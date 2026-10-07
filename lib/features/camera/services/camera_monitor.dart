import 'dart:async';
import 'dart:io';

import 'package:battery_plus/battery_plus.dart';
import 'package:camera/camera.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../core/logging/app_logger.dart';
import '../../../core/models/enums.dart';
import '../../../core/storage/org_database.dart';
import '../../../core/time/clock.dart';
import '../../ai/gemini/gemini_client.dart';
import '../../ai/local/activity_sampler.dart';
import '../../ai/local/motion_detector.dart';
import '../../ai/local/object_detector.dart';
import '../../ai/local/scene_narration.dart';
import '../../live_stream/data/local_live_relay.dart';
import '../../incidents/data/sync_worker.dart';
import '../../incidents/domain/incident.dart';
import '../../settings/domain/app_settings.dart';
import 'circular_video_buffer.dart';
import 'monitoring_engine.dart';
import '../domain/camera_device.dart';
import '../../zones/domain/zone_geometry.dart';

class CameraMonitor extends ChangeNotifier {
  CameraMonitor({
    required this.database,
    required this.engine,
    required this.sampler,
    required this.gemini,
    required this.settings,
    required this.camera,
    required this.clock,
    required this.organizationId,
    required this.userId,
    this.detector,
  });

  final OrgDatabase database;
  final MonitoringEngine engine;
  final ActivitySampler sampler;
  final GeminiSceneClient gemini;
  final AppSettings settings;
  final CameraDevice camera;
  final Clock clock;
  final String organizationId;
  final String userId;
  final ObjectDetector? detector;
  final logger = const AppLogger('camera');
  final motion = MotionDetector();
  final frames = FrameRing();
  final outbox = <OutboxJob>[];
  final relay = LocalLiveRelay();

  CameraController? controller;
  bool monitoring = false;
  bool busy = false;
  bool cloudOffline = false;
  bool permissionDenied = false;
  String? failure;
  String activity = 'Looking at the camera view.';
  String? ownerLiveAddress;
  int people = 0;
  RiskLevel risk = RiskLevel.normal;
  int? battery;
  bool charging = false;
  List<CameraDescription> cameras = const [];
  int cameraIndex = 0;
  var _processing = false;
  Timer? _heartbeat;
  Timer? _postRoll;
  var _dimmed = false;
  var _blocked = false;
  var _lastMotion = 0.0;
  DateTime? _lastJpegAt;
  DateTime? _lastUiAt;
  DeviceHeartbeat? _lastHeartbeat;
  List<Detection> _lastDetections = const [];
  List<SecurityZone> _zoneCache = const [];
  DateTime? _zonesLoadedAt;

  bool get dimmed => _dimmed;

  /// Which on-device model is naming what the camera sees.
  String get detectorLabel => detector?.name.toUpperCase() ?? 'MOTION ONLY';

  Future<void> initialize() async {
    try {
      cameras = await availableCameras();
      if (cameras.isEmpty) {
        failure = 'No camera is available on this phone.';
        notifyListeners();
        return;
      }
      await _open(cameras[cameraIndex]);
      await relay.start(
        cameraId: camera.id,
        cameraName: camera.name,
        organizationId: organizationId,
      );
      relay.setCamera(camera.toJson());
      ownerLiveAddress = relay.ownerUrl;
      await _listen();
      if (camera.id != 'pending') await start();
      notifyListeners();
    } catch (error, stack) {
      failure = 'Camera is unavailable.';
      logger.error('camera init', error: error, stackTrace: stack);
      notifyListeners();
    }
  }

  Future<void> flip() async {
    if (cameras.length < 2) return;
    cameraIndex = (cameraIndex + 1) % cameras.length;
    await _open(cameras[cameraIndex]);
    await _listen();
  }

  Future<void> start() async {
    if (controller == null || monitoring) return;
    monitoring = true;
    failure = null;
    await WakelockPlus.enable();
    await _listen();
    _heartbeat?.cancel();
    _heartbeat = Timer.periodic(const Duration(seconds: 20), (_) => _beat());
    await _beat();
    notifyListeners();
  }

  Future<void> stop() async {
    monitoring = false;
    _heartbeat?.cancel();
    _postRoll?.cancel();
    await WakelockPlus.disable();
    await _beat(offline: true);
    notifyListeners();
  }

  void toggleDim() {
    _dimmed = !_dimmed;
    notifyListeners();
  }

  Future<void> _open(CameraDescription description) async {
    final previous = controller;
    if (previous != null) {
      controller = null;
      notifyListeners();
      if (previous.value.isStreamingImages) {
        try {
          await previous.stopImageStream();
        } on CameraException {
          // The stream may already be stopped.
        }
      }
      await previous.dispose();
    }
    final preset = switch (settings.dataSaver) {
      DataSaverMode.lowData => ResolutionPreset.low,
      DataSaverMode.balanced => ResolutionPreset.medium,
      DataSaverMode.highQuality => ResolutionPreset.high,
    };
    final next = CameraController(description, preset, enableAudio: false);
    controller = next;
    try {
      await next.initialize();
      permissionDenied = false;
      failure = null;
    } on CameraException catch (error) {
      permissionDenied = error.code == 'CameraAccessDenied';
      failure = permissionDenied
          ? 'Camera permission is required for monitoring.'
          : 'Camera is unavailable.';
    }
    notifyListeners();
  }

  Future<void> _listen() async {
    final active = controller;
    if (active == null || !active.value.isInitialized) return;
    if (active.value.isStreamingImages) return;
    await active.startImageStream((image) async {
      if (_processing) return;
      _processing = true;
      try {
        await _onFrame(image);
      } catch (error, stack) {
        logger.error('frame', error: error, stackTrace: stack);
      } finally {
        _processing = false;
      }
    });
  }

  Future<void> _onFrame(CameraImage image) async {
    final gray = _gray(image, 96, 54);
    final motionSample = motion.sample(gray);
    final now = clock.now();
    final captureStill = _lastJpegAt == null ||
        now.difference(_lastJpegAt!) >= const Duration(milliseconds: 250);
    final jpeg = captureStill ? _colorJpeg(image, settings.dataSaver) : Uint8List(0);
    if (captureStill) {
      frames.add(CapturedFrame(bytes: jpeg, capturedAt: now));
      _lastJpegAt = now;
      relay.update(jpeg: jpeg);
    }
    _lastMotion = motionSample.score;
    _blocked = motionSample.obstructed;
    List<Detection> detections = const [];
    final activeDetector = detector;
    if (activeDetector != null && captureStill) {
      try {
        detections = await activeDetector.detect(
          DetectorFrame(bytes: gray, width: 96, height: 54, jpeg: jpeg),
        );
      } catch (error) {
        logger.error('detector', error: error);
      }
    } else {
      detections = _lastDetections;
    }
    _lastDetections = detections;
    if (_zonesLoadedAt == null || now.difference(_zonesLoadedAt!) > const Duration(seconds: 5)) {
      final zones = await database.watchZones(organizationId).first;
      _zoneCache = zones.where((zone) => zone.cameraId == camera.id).toList();
      _zonesLoadedAt = now;
    }
    engine.zones = _zoneCache;
    final online = await _online();
    final snapshot = engine.tick(
      detections: detections,
      motionScore: motionSample.score,
      obstructed: motionSample.obstructed,
      now: now,
      geminiFailed: !online,
    );
    people = snapshot.peopleCount;
    risk = snapshot.decision.level;
    activity = describeScene(
      detections: detections,
      motionScore: motionSample.score,
      blocked: motionSample.obstructed,
      restricted: snapshot.observation.restrictedOccupied,
      zoneName: snapshot.observation.occupiedZoneName,
    );
    cloudOffline = !online;
    relay.update(activity: activity);
    if (captureStill &&
        jpeg.isNotEmpty &&
        sampler.shouldSample(
          now: now,
          peopleCount: people,
          motionScore: motionSample.score,
          potentialIncident: snapshot.decision.openIncident || risk.rank >= RiskLevel.medium.rank,
        )) {
      unawaited(_askGemini(jpeg, snapshot));
    }
    if (monitoring && snapshot.openIncident) {
      await _openIncident(snapshot, now);
    }
    final writer = const HeartbeatWriter();
    final next = _heartbeatFor(snapshot, online);
    if (writer.shouldWrite(previous: _lastHeartbeat, next: next, now: now)) {
      await _publish(next);
    }
    final narrated = activity != _lastHeartbeat?.activity;
    if (narrated || _lastUiAt == null || now.difference(_lastUiAt!) >= const Duration(milliseconds: 300)) {
      _lastUiAt = now;
      notifyListeners();
    }
  }

  Future<void> _askGemini(Uint8List jpeg, MonitoringSnapshot snapshot) async {
    try {
      final update = await gemini.interpret(
        organizationId: organizationId,
        cameraId: camera.id,
        jpeg: jpeg,
        state: snapshot.scene,
        context: {
          'camera_name': camera.name,
          'schedule_armed': engine.schedule.isArmed(clock.now()),
          'motion': snapshot.decision.localScore,
        },
      );
      if (update == null) {
        cloudOffline = true;
        notifyListeners();
        return;
      }
      final fused = engine.tick(
        detections: _lastDetections,
        motionScore: _lastMotion,
        obstructed: _blocked,
        now: clock.now(),
        gemini: update,
      );
      people = fused.peopleCount;
      risk = fused.decision.level;
      cloudOffline = false;
      relay.update(activity: activity);
      if (fused.openIncident) await _openIncident(fused, clock.now());
      notifyListeners();
    } catch (error) {
      cloudOffline = true;
      logger.error('gemini', error: error);
    }
  }

  Future<void> _openIncident(MonitoringSnapshot snapshot, DateTime now) async {
    final directory = await getApplicationSupportDirectory();
    final clipDir = Directory('${directory.path}/incidents/${camera.id}_${now.millisecondsSinceEpoch}');
    clipDir.createSync(recursive: true);
    final selected = frames.between(now.subtract(Duration(seconds: engine.rule.preRollSeconds)), now);
    for (var i = 0; i < selected.length; i++) {
      File('${clipDir.path}/pre_$i.jpg').writeAsBytesSync(selected[i].bytes);
    }
    final incident = Incident(
      id: 'inc_${now.microsecondsSinceEpoch}',
      organizationId: organizationId,
      cameraId: camera.id,
      cameraName: camera.name,
      createdAt: now,
      eventStart: now.subtract(Duration(seconds: engine.rule.preRollSeconds)),
      eventEnd: now.add(Duration(seconds: engine.rule.postRollSeconds)),
      riskLevel: snapshot.decision.level,
      riskScore: snapshot.decision.score,
      eventType: snapshot.scene.activity,
      description: snapshot.decision.description,
      observations: snapshot.decision.observations,
      aiConfidence: 0.7,
      status: IncidentStatus.recording,
      reviewState: ReviewState.unreviewed,
      createdByEngine: 'event_risk_engine',
      zoneName: snapshot.observation.occupiedZoneName,
      localClipPath: clipDir.path,
    );
    await _saveIncident(incident);
    _postRoll?.cancel();
    _postRoll = Timer(Duration(seconds: engine.rule.postRollSeconds), () async {
      final end = clock.now();
      final more = frames.between(now, end);
      for (var i = 0; i < more.length; i++) {
        File('${clipDir.path}/post_$i.jpg').writeAsBytesSync(more[i].bytes, flush: true);
      }
      await _saveIncident(incident.copyWith(status: IncidentStatus.ready, eventEnd: end));
    });
  }

  Future<void> _saveIncident(Incident incident) async {
    try {
      await database.saveIncident(incident);
      final online = await _online();
      if (!online) {
        outbox.add(OutboxJob(
          id: incident.id,
          type: 'incident.metadata',
          payload: incident.toJson(),
        ));
      }
    } catch (error) {
      outbox.add(OutboxJob(
        id: incident.id,
        type: 'incident.metadata',
        payload: incident.toJson(),
      ));
      logger.error('incident save', error: error);
    }
  }

  Future<void> flushOutbox() async {
    if (!await _online()) return;
    final worker = const SyncWorker();
    final remaining = await worker.flush(
      online: true,
      jobs: List.of(outbox),
      send: (job) => database.saveIncident(Incident.fromJson(job.payload)),
    );
    outbox
      ..clear()
      ..addAll(remaining);
  }

  DeviceHeartbeat _heartbeatFor(MonitoringSnapshot snapshot, bool online) {
    return DeviceHeartbeat(
      operationalState: monitoring ? OperationalState.monitoring : OperationalState.offline,
      aiStatus: online ? AiStatus.active : AiStatus.cloudOffline,
      monitoredAt: clock.now(),
      charging: charging,
      peopleCount: snapshot.peopleCount,
      riskLevel: snapshot.decision.level,
      riskScore: snapshot.decision.score,
      activity: activity,
      networkQuality: online ? NetworkQuality.good : NetworkQuality.poor,
      cloudAiOnline: online,
      cameraBlocked: _blocked,
      batteryPercent: battery,
    );
  }

  Future<void> _publish(DeviceHeartbeat heartbeat) async {
    _lastHeartbeat = heartbeat;
    final updated = camera.copyWith(monitoring: monitoring, heartbeat: heartbeat);
    relay.setCamera(updated.toJson());
    try {
      await database.saveCamera(updated);
    } catch (error) {
      outbox.add(OutboxJob(id: 'hb_${heartbeat.monitoredAt.millisecondsSinceEpoch}', type: 'heartbeat', payload: updated.toJson()));
      logger.error('heartbeat', error: error);
    }
  }

  Future<void> _beat({bool offline = false}) async {
    try {
      final state = await Battery().batteryState;
      charging = state == BatteryState.charging || state == BatteryState.full;
      battery = await Battery().batteryLevel;
    } catch (_) {}
    final online = await _online();
    final heartbeat = DeviceHeartbeat(
      operationalState: offline ? OperationalState.offline : OperationalState.monitoring,
      aiStatus: online ? AiStatus.active : AiStatus.cloudOffline,
      monitoredAt: clock.now(),
      charging: charging,
      peopleCount: people,
      riskLevel: risk,
      riskScore: risk.rank * 20,
      activity: activity,
      networkQuality: online ? NetworkQuality.good : NetworkQuality.poor,
      cloudAiOnline: online,
      cameraBlocked: false,
      batteryPercent: battery,
    );
    _lastHeartbeat = heartbeat;
    await _publish(heartbeat);
    await flushOutbox();
    notifyListeners();
  }

  Future<bool> _online() async {
    try {
      final result = await Connectivity().checkConnectivity();
      return !result.contains(ConnectivityResult.none);
    } catch (_) {
      return false;
    }
  }

  Uint8List _gray(CameraImage image, int width, int height) {
    final y = image.planes.first.bytes;
    final rowStride = image.planes.first.bytesPerRow;
    final output = Uint8List(width * height);
    for (var yy = 0; yy < height; yy++) {
      final srcY = (yy * image.height / height).floor();
      for (var xx = 0; xx < width; xx++) {
        final srcX = (xx * image.width / width).floor();
        final index = srcY * rowStride + srcX;
        output[yy * width + xx] = index < y.length ? y[index] : 0;
      }
    }
    return output;
  }

  /// Colour frame used for three things at once: the on-device model, the
  /// owner's live view, and incident clips. Object models cannot work on the
  /// tiny grayscale buffer the motion detector uses.
  Uint8List _colorJpeg(CameraImage image, DataSaverMode mode) {
    final (width, height, quality) = switch (mode) {
      DataSaverMode.lowData => (320, 180, 50),
      DataSaverMode.balanced => (480, 270, 60),
      DataSaverMode.highQuality => (640, 360, 72),
    };
    final decoded = img.Image(width: width, height: height);
    final bgra = image.format.group == ImageFormatGroup.bgra8888;
    final yPlane = image.planes.first;
    final uPlane = image.planes.length > 1 ? image.planes[1] : null;
    final vPlane = image.planes.length > 2 ? image.planes[2] : null;
    for (var yy = 0; yy < height; yy++) {
      final srcY = (yy * image.height / height).floor();
      for (var xx = 0; xx < width; xx++) {
        final srcX = (xx * image.width / width).floor();
        if (bgra) {
          final index = srcY * yPlane.bytesPerRow + srcX * 4;
          if (index + 2 >= yPlane.bytes.length) continue;
          decoded.setPixelRgb(
            xx,
            yy,
            yPlane.bytes[index + 2],
            yPlane.bytes[index + 1],
            yPlane.bytes[index],
          );
        } else {
          final yIndex = srcY * yPlane.bytesPerRow + srcX;
          final yValue = yIndex < yPlane.bytes.length ? yPlane.bytes[yIndex] : 0;
          var red = yValue;
          var green = yValue;
          var blue = yValue;
          if (uPlane != null && vPlane != null) {
            final uvX = srcX ~/ 2;
            final uvY = srcY ~/ 2;
            final uStep = uPlane.bytesPerPixel ?? 1;
            final vStep = vPlane.bytesPerPixel ?? 1;
            final uIndex = uvY * uPlane.bytesPerRow + uvX * uStep;
            final vIndex = uvY * vPlane.bytesPerRow + uvX * vStep;
            final u = uIndex < uPlane.bytes.length ? uPlane.bytes[uIndex] : 128;
            final v = vIndex < vPlane.bytes.length ? vPlane.bytes[vIndex] : 128;
            final c = yValue - 16;
            final d = u - 128;
            final e = v - 128;
            red = ((298 * c + 409 * e + 128) >> 8).clamp(0, 255);
            green = ((298 * c - 100 * d - 208 * e + 128) >> 8).clamp(0, 255);
            blue = ((298 * c + 516 * d + 128) >> 8).clamp(0, 255);
          }
          decoded.setPixelRgb(xx, yy, red, green, blue);
        }
      }
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: quality));
  }

  @override
  Future<void> dispose() async {
    _heartbeat?.cancel();
    _postRoll?.cancel();
    await relay.stop();
    final previous = controller;
    controller = null;
    await WakelockPlus.disable();
    await previous?.dispose();
    await detector?.dispose();
    super.dispose();
  }
}
