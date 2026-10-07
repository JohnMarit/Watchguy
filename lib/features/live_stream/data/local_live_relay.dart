import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

const localLivePort = 47821;
const localLiveBeaconPort = 47822;

class LocalCameraFeed {
  const LocalCameraFeed({
    required this.cameraId,
    required this.name,
    required this.host,
    required this.port,
    required this.activity,
    required this.seenAt,
    this.organizationId = '',
    this.camera,
    this.pinned = false,
  });

  final String cameraId;
  final String name;
  final String host;
  final int port;
  final String activity;
  final DateTime seenAt;
  final String organizationId;

  /// The camera record as the camera phone knows it, used by a dashboard on the
  /// same network when there is no shared backend.
  final Map<String, dynamic>? camera;
  final bool pinned;

  Uri get frameUri => Uri.parse('http://$host:$port/frame.jpg');
}

/// Serves the latest camera frame on the local network and announces it.
class LocalLiveRelay {
  HttpServer? _server;
  RawDatagramSocket? _socket;
  Timer? _beacon;
  Uint8List? _frame;
  String _activity = 'Nothing is happening in view.';
  String cameraId = '';
  String cameraName = '';
  String organizationId = '';
  String? address;
  Map<String, dynamic>? _camera;

  String? get ownerUrl => address == null ? null : 'http://$address:$localLivePort';

  Future<void> start({
    required String cameraId,
    required String cameraName,
    String organizationId = '',
  }) async {
    this.cameraId = cameraId;
    this.cameraName = cameraName;
    this.organizationId = organizationId;
    if (_server != null) return;
    _server = await HttpServer.bind(InternetAddress.anyIPv4, localLivePort, shared: true);
    address = await _localIpv4();
    _server!.listen(_handle, onError: (_) {});
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _socket!.broadcastEnabled = true;
    } catch (_) {}
    _beacon = Timer.periodic(const Duration(seconds: 2), (_) => announce());
    announce();
  }

  void update({Uint8List? jpeg, String? activity}) {
    if (jpeg != null && jpeg.isNotEmpty) _frame = Uint8List.fromList(jpeg);
    if (activity != null && activity.isNotEmpty) _activity = activity;
  }

  void setCamera(Map<String, dynamic> camera) {
    _camera = camera;
    cameraId = camera['id'] as String? ?? cameraId;
    cameraName = camera['name'] as String? ?? cameraName;
    organizationId = camera['organizationId'] as String? ?? organizationId;
  }

  void announce() {
    final socket = _socket;
    if (socket == null) return;
    final payload = utf8.encode(jsonEncode({
      'v': 1,
      'cameraId': cameraId,
      'name': cameraName,
      'org': organizationId,
      'port': _server?.port ?? localLivePort,
      'activity': _activity,
      'camera': _camera,
    }));
    try {
      socket.send(payload, InternetAddress('255.255.255.255'), localLiveBeaconPort);
    } catch (_) {}
  }

  Future<void> stop() async {
    _beacon?.cancel();
    _beacon = null;
    _socket?.close();
    _socket = null;
    await _server?.close(force: true);
    _server = null;
  }

  Future<void> _handle(HttpRequest request) async {
    final response = request.response;
    try {
      if (request.uri.path == '/frame.jpg') {
        final frame = _frame;
        if (frame == null) {
          response.statusCode = HttpStatus.noContent;
        } else {
          response.headers.contentType = ContentType('image', 'jpeg');
          response.headers.set('cache-control', 'no-store');
          response.add(frame);
        }
      } else if (request.uri.path == '/status') {
        response.headers.contentType = ContentType.json;
        response.write(jsonEncode({
          'cameraId': cameraId,
          'name': cameraName,
          'activity': _activity,
        }));
      } else {
        response.statusCode = HttpStatus.notFound;
      }
    } catch (_) {
      response.statusCode = HttpStatus.internalServerError;
    } finally {
      await response.close();
    }
  }
}

class LocalLiveDirectory extends ChangeNotifier {
  LocalLiveDirectory._();

  static final instance = LocalLiveDirectory._();

  final feeds = <String, LocalCameraFeed>{};
  RawDatagramSocket? _socket;
  Timer? _prune;
  var _starting = false;

  Future<void> start() async {
    if (_socket != null || _starting) return;
    _starting = true;
    try {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        localLiveBeaconPort,
        reuseAddress: true,
      );
      socket.broadcastEnabled = true;
      _socket = socket;
      socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        _remember(datagram);
      });
      _prune ??= Timer.periodic(const Duration(seconds: 3), (_) => _dropStale());
    } catch (_) {
      // Another copy of the app, or this platform, may already own the beacon port.
    } finally {
      _starting = false;
    }
  }

  LocalCameraFeed? feedFor(String cameraId) => feeds[cameraId];

  void pin({required String cameraId, required String address, String name = ''}) {
    final text = address.trim();
    if (text.isEmpty) return;
    final uri = Uri.tryParse(text.startsWith('http') ? text : 'http://$text');
    if (uri == null || uri.host.isEmpty) return;
    final existing = feeds[cameraId];
    feeds[cameraId] = LocalCameraFeed(
      cameraId: cameraId,
      name: name.isEmpty ? existing?.name ?? 'Camera' : name,
      host: uri.host,
      port: uri.hasPort ? uri.port : localLivePort,
      activity: existing?.activity ?? '',
      seenAt: DateTime.now(),
      pinned: true,
    );
    notifyListeners();
  }

  void _remember(Datagram datagram) {
    try {
      final decoded = jsonDecode(utf8.decode(datagram.data));
      if (decoded is! Map) return;
      final cameraId = decoded['cameraId']?.toString() ?? '';
      if (cameraId.isEmpty) return;
      final existing = feeds[cameraId];
      final host = existing?.pinned == true ? existing!.host : datagram.address.address;
      if (host.isEmpty || host == '0.0.0.0') return;
      final camera = decoded['camera'];
      feeds[cameraId] = LocalCameraFeed(
        cameraId: cameraId,
        name: decoded['name']?.toString() ?? existing?.name ?? 'Camera',
        host: host,
        port: existing?.pinned == true
            ? existing!.port
            : (decoded['port'] as num?)?.toInt() ?? localLivePort,
        activity: decoded['activity']?.toString() ?? '',
        seenAt: DateTime.now(),
        organizationId: decoded['org']?.toString() ?? existing?.organizationId ?? '',
        camera: camera is Map ? Map<String, dynamic>.from(camera) : existing?.camera,
        pinned: existing?.pinned ?? false,
      );
      notifyListeners();
    } catch (_) {}
  }

  void _dropStale() {
    final cutoff = DateTime.now().subtract(const Duration(seconds: 8));
    final before = feeds.length;
    feeds.removeWhere((_, feed) => !feed.pinned && feed.seenAt.isBefore(cutoff));
    if (feeds.length != before) notifyListeners();
  }
}

Future<String?> _localIpv4() async {
  try {
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
      includeLinkLocal: false,
    );
    for (final interface in interfaces) {
      for (final address in interface.addresses) {
        if (!address.isLoopback) return address.address;
      }
    }
  } catch (_) {}
  return null;
}
