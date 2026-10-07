import 'package:flutter_test/flutter_test.dart';
import 'package:watchguy/core/models/enums.dart';
import 'package:watchguy/core/storage/document_store.dart';
import 'package:watchguy/core/storage/org_database.dart';
import 'package:watchguy/features/camera/domain/camera_device.dart';
import 'package:watchguy/features/camera/services/circular_video_buffer.dart';
import 'package:watchguy/features/dashboard/domain/dashboard_summary.dart';
import 'package:watchguy/features/incidents/data/sync_worker.dart';
import 'package:watchguy/features/incidents/domain/incident.dart';

void main() {
  test('the rolling buffer keeps the pre-event window and the incident plan includes it', () {
    final buffer = CircularVideoBuffer();
    final trigger = DateTime.utc(2026, 1, 1, 23, 42);
    buffer.add(CapturedSegment(
      path: 'old.mp4',
      startedAt: trigger.subtract(const Duration(seconds: 30)),
      endedAt: trigger.subtract(const Duration(seconds: 25)),
    ));
    buffer.add(CapturedSegment(
      path: 'pre.mp4',
      startedAt: trigger.subtract(const Duration(seconds: 10)),
      endedAt: trigger.subtract(const Duration(seconds: 5)),
    ));
    final post = CapturedSegment(
      path: 'post.mp4',
      startedAt: trigger,
      endedAt: trigger.add(const Duration(seconds: 20)),
    );
    final plan = buffer.freeze(trigger: trigger, postRoll: const Duration(seconds: 20), postSegments: [post]);
    expect(plan.segments.map((segment) => segment.path), ['pre.mp4', 'post.mp4']);
    expect(plan.eventStart, trigger.subtract(const Duration(seconds: 10)));
  });

  test('incident upload failure stays queued until the network returns', () async {
    const worker = SyncWorker();
    final job = OutboxJob(id: 'inc', type: 'incident.metadata', payload: {'id': 'inc'});
    final offline = await worker.flush(online: false, jobs: [job], send: (_) async {});
    expect(offline, [job]);
    final failed = await worker.flush(
      online: true,
      jobs: [job],
      send: (_) async => throw Exception('upload failed'),
    );
    expect(failed.single.attempts, 1);
    expect(failed.single.lastError, contains('upload'));
    final done = await worker.flush(online: true, jobs: failed, send: (_) async {});
    expect(done, isEmpty);
  });

  test('camera offline, low battery, and restart retry are explicit states', () async {
    final now = DateTime.utc(2026, 1, 1, 12);
    final camera = CameraDevice(
      id: 'cam',
      organizationId: 'org',
      name: 'Gate',
      location: 'Front',
      operatorUserId: 'user',
      deviceId: 'phone',
      createdAt: now,
      monitoring: true,
      heartbeat: DeviceHeartbeat(
        operationalState: OperationalState.monitoring,
        aiStatus: AiStatus.failed,
        monitoredAt: now.subtract(const Duration(minutes: 2)),
        charging: false,
        peopleCount: 0,
        riskLevel: RiskLevel.normal,
        riskScore: 0,
        activity: '',
        networkQuality: NetworkQuality.poor,
        cloudAiOnline: false,
        cameraBlocked: true,
        batteryPercent: 8,
      ),
    );
    expect(isCameraOnline(camera.heartbeat, now), isFalse);
    expect(cameraHealthFlags(camera, now), containsAll(['OFFLINE', 'LOW BATTERY', 'CAMERA BLOCKED', 'AI DISABLED']));
    const retry = RetrySchedule();
    expect(retry.delayFor(0), const Duration(seconds: 1));
    expect(retry.delayFor(3), const Duration(seconds: 8));
    expect(retry.exhausted(8), isTrue);

    final database = LocalOrgDatabase(MemoryDocumentStore());
    final incident = Incident(
      id: 'inc',
      organizationId: 'org',
      cameraId: 'cam',
      cameraName: 'Gate',
      createdAt: now,
      eventStart: now.subtract(const Duration(seconds: 10)),
      eventEnd: now.add(const Duration(seconds: 20)),
      riskLevel: RiskLevel.high,
      riskScore: 82,
      eventType: 'restricted_area_entry',
      description: 'Two people entered the restricted loading area.',
      observations: const ['Both crossed the restricted-zone boundary'],
      aiConfidence: 0.8,
      status: IncidentStatus.ready,
      reviewState: ReviewState.unreviewed,
      createdByEngine: 'event_risk_engine',
    );
    await database.saveIncident(incident);
    final saved = await database.watchIncidents('org').first;
    expect(saved.single.riskLevel, RiskLevel.high);
    expect(shouldNotifyRisk(saved.single.riskLevel), isTrue);
    expect(shouldNotifyRisk(RiskLevel.low), isFalse);
    final summary = DashboardSummary.fromCameras([camera], now);
    expect(summary.offline, 1);
    expect(summary.alerts, 0);
  });
}
