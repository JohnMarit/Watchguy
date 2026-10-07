import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:livekit_client/livekit_client.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../camera/domain/camera_device.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../data/livekit_token_client.dart';
import '../data/local_live_relay.dart';
import '../domain/live_session.dart';
import 'local_frame_view.dart';

class LiveViewScreen extends ConsumerStatefulWidget {
  const LiveViewScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<LiveViewScreen> createState() => _LiveViewScreenState();
}

class _LiveViewScreenState extends ConsumerState<LiveViewScreen> {
  final address = TextEditingController();
  Room? room;
  String? message;
  VideoTrack? track;

  @override
  void initState() {
    super.initState();
    Future.microtask(_connect);
  }

  @override
  void dispose() {
    address.dispose();
    room?.disconnect();
    room?.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final session = ref.read(sessionControllerProvider);
    final org = session.organization;
    final user = session.user;
    if (org == null || user == null) return;
    if (!ref.read(appConfigProvider).apiConfigured) return;
    final database = ref.read(orgDatabaseProvider);
    final live = LiveSession(
      id: const Uuid().v4(),
      organizationId: org.id,
      cameraId: widget.cameraId,
      requestedBy: user.id,
      state: LiveSessionState.requested,
      createdAt: ref.read(clockProvider).now(),
    );
    await database.saveLiveSession(live);
    try {
      final credentials = await LiveKitTokenClient(ref.read(apiClientProvider)).issue(
        organizationId: org.id,
        cameraId: widget.cameraId,
        role: LiveRole.subscriber,
      );
      final next = Room();
      await next.connect(credentials.url, credentials.token);
      next.addListener(_syncTrack);
      setState(() {
        room = next;
        message = null;
      });
      _syncTrack();
      await database.saveLiveSession(live.copyWith(state: LiveSessionState.active));
    } catch (error) {
      setState(() => message = error.toString());
    }
  }

  /// The camera announces itself on the local network, so the box starts with
  /// the address it last announced instead of an empty field.
  String _sampleAddress() {
    final feed = LocalLiveDirectory.instance.feedFor(widget.cameraId);
    if (feed == null) return 'http://192.168.1.20:$localLivePort';
    return 'http://${feed.host}:${feed.port}';
  }

  void _syncTrack() {
    final current = room;
    if (current == null) return;
    VideoTrack? found;
    for (final participant in current.remoteParticipants.values) {
      for (final publication in participant.videoTrackPublications) {
        found = publication.track;
      }
    }
    if (mounted) setState(() => track = found);
  }

  @override
  Widget build(BuildContext context) {
    final activeTrack = track;
    final cameras = ref.watch(camerasProvider).value ?? const <CameraDevice>[];
    final camera = cameras.where((item) => item.id == widget.cameraId).firstOrNull;
    return Scaffold(
      appBar: AppBar(title: Text(camera?.name ?? 'Live view')),
      body: Column(
        children: [
          Expanded(
            child: activeTrack == null
                ? LocalFrameView(cameraId: widget.cameraId, cameraName: camera?.name ?? '')
                : VideoTrackRenderer(activeTrack),
          ),
          if (message != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
              child: Text(message!, style: const TextStyle(color: AppColors.warning)),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              children: [
                TextField(
                  controller: address,
                  autocorrect: false,
                  decoration: InputDecoration(
                    labelText: 'Camera address',
                    hintText: _sampleAddress(),
                  ),
                ),
                const SizedBox(height: 8),
                SecondaryButton(
                  label: 'Watch this address',
                  onPressed: () {
                    LocalLiveDirectory.instance.pin(
                      cameraId: widget.cameraId,
                      address: address.text.trim().isEmpty ? _sampleAddress() : address.text,
                      name: camera?.name ?? '',
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MultiCameraScreen extends ConsumerWidget {
  const MultiCameraScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameras = ref.watch(camerasProvider).value ?? const <CameraDevice>[];
    final visible = cameras.take(4).toList();
    return Scaffold(
      appBar: AppBar(title: const Text('All cameras')),
      body: visible.isEmpty
          ? const Center(child: Text('No cameras paired yet.'))
          : GridView.count(
              crossAxisCount: 2,
              padding: const EdgeInsets.all(12),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 0.78,
              children: visible
                  .map(
                    (camera) => InkWell(
                      onTap: () => context.push('/dashboard/cameras/${camera.id}/live'),
                      borderRadius: BorderRadius.circular(18),
                      child: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: AppColors.line),
                          gradient: AppGradients.surface,
                        ),
                        clipBehavior: Clip.antiAlias,
                        child: Column(
                          children: [
                            Expanded(
                              child: LocalFrameView(
                                cameraId: camera.id,
                                cameraName: camera.name,
                                compact: true,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(10),
                              child: Text(
                                camera.name.toUpperCase(),
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}
