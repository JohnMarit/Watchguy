import '../../../core/logging/app_logger.dart';
import '../../../core/storage/org_database.dart';
import '../../camera/domain/camera_device.dart';
import 'local_live_relay.dart';

/// Copies cameras announced on the local network into this device's own store.
/// Without a shared backend a camera paired on another phone would otherwise be
/// invisible to the owner's dashboard.
class LocalCameraMirror {
  LocalCameraMirror({required this.database, required this.organizationId});

  final OrgDatabase database;
  final String organizationId;
  final _logger = const AppLogger('mirror');
  final _directory = LocalLiveDirectory.instance;
  final _lastSeen = <String, DateTime>{};
  var _started = false;

  void start() {
    if (_started) return;
    _started = true;
    _directory.start();
    _directory.addListener(_sync);
    _sync();
  }

  void dispose() {
    if (!_started) return;
    _directory.removeListener(_sync);
    _started = false;
  }

  void _sync() {
    for (final feed in _directory.feeds.values) {
      final json = feed.camera;
      if (json == null) continue;
      if (feed.organizationId.isNotEmpty && feed.organizationId != organizationId) continue;
      try {
        final camera = CameraDevice.fromJson(json);
        if (camera.organizationId != organizationId) continue;
        final previous = _lastSeen[camera.id];
        final stamp = camera.heartbeat.monitoredAt;
        if (previous != null && !stamp.isAfter(previous)) continue;
        _lastSeen[camera.id] = stamp;
        database.saveCamera(camera);
      } catch (error) {
        _logger.error('mirror camera', error: error);
      }
    }
  }
}
