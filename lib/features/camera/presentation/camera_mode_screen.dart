import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/providers.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../ai/local/activity_sampler.dart';
import '../../ai/local/motion_blob_detector.dart';
import '../../ai/local/yolo_object_detector.dart';
import '../../camera/domain/camera_device.dart';
import '../../camera/services/camera_monitor.dart';
import '../../camera/services/monitoring_engine.dart';
import '../../zones/domain/monitoring_schedule.dart';

class CameraModeScreen extends ConsumerStatefulWidget {
  const CameraModeScreen({super.key});

  @override
  ConsumerState<CameraModeScreen> createState() => _CameraModeScreenState();
}

class _CameraModeScreenState extends ConsumerState<CameraModeScreen> {
  CameraMonitor? monitor;

  @override
  void initState() {
    super.initState();
    Future.microtask(_boot);
  }

  Future<void> _boot() async {
    final session = ref.read(sessionControllerProvider);
    final org = session.organization;
    final user = session.user;
    if (org == null || user == null) return;
    final database = ref.read(orgDatabaseProvider);
    final cameras = await database.watchCameras(org.id).first;
    final existing = cameras.cast<CameraDevice?>().firstWhere(
          (camera) => camera?.id == session.settings.activeCameraId,
          orElse: () => cameras.isEmpty ? null : cameras.first,
        );
    final camera = existing ??
        CameraDevice(
          id: 'pending',
          organizationId: org.id,
          name: 'Unpaired camera',
          location: '',
          operatorUserId: user.id,
          deviceId: session.settings.deviceId,
          createdAt: ref.read(clockProvider).now(),
          monitoring: false,
          heartbeat: DeviceHeartbeat.idle(ref.read(clockProvider).now()),
        );
    final rule = await database.ruleFor(org.id, cameraId: camera.id);
    final created = CameraMonitor(
      database: database,
      engine: MonitoringEngine(rule: rule, schedule: camera.schedule, cameraId: camera.id),
      sampler: ActivitySampler(ref.read(samplingPolicyProvider)),
      gemini: ref.read(geminiClientProvider),
      settings: session.settings,
      camera: camera,
      clock: ref.read(clockProvider),
      organizationId: org.id,
      userId: user.id,
      detector: FallbackDetector(
        primary: YoloObjectDetector(),
        fallback: MotionBlobDetector(),
      ),
    );
    await created.initialize();
    if (!mounted) return;
    setState(() => monitor = created);
  }

  @override
  void dispose() {
    monitor?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final active = monitor;
    if (active == null) {
      return const Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Align(alignment: Alignment.centerRight, child: _SignOutButton()),
              Expanded(child: Center(child: CircularProgressIndicator())),
            ],
          ),
        ),
      );
    }
    return AnimatedBuilder(
      animation: active,
      builder: (context, _) {
        final controller = active.controller;
        final previewReady = controller != null && controller.value.isInitialized;
        return Scaffold(
          backgroundColor: Colors.black,
          body: Stack(
            fit: StackFit.expand,
            children: [
              if (previewReady)
                Opacity(
                  opacity: active.dimmed ? 0.3 : 1,
                  child: _LivePreview(controller: controller),
                )
              else
                const ColoredBox(color: Colors.black),
              const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.overlay)),
              Align(
                alignment: Alignment.bottomCenter,
                child: FractionallySizedBox(
                  heightFactor: 0.62,
                  child: const DecoratedBox(decoration: BoxDecoration(gradient: AppGradients.panel)),
                ),
              ),
              SafeArea(
                child: Column(
                  children: [
                    _TopBar(monitor: active),
                    const Spacer(),
                    _BottomPanel(monitor: active),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.monitor});

  final CameraMonitor monitor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 8, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  monitor.camera.name.toUpperCase(),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: 0.4),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    const InfoChip(label: 'WATCHING', icon: Icons.visibility_outlined, color: AppColors.online),
                    InfoChip(
                      label: monitor.monitoring ? 'RECORDING' : 'NOT RECORDING',
                      icon: monitor.monitoring ? Icons.fiber_manual_record : Icons.pause,
                      color: monitor.monitoring ? AppColors.critical : AppColors.muted,
                    ),
                    InfoChip(
                      label: monitor.detectorLabel,
                      icon: Icons.auto_awesome,
                      color: AppColors.redBright,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const _SignOutButton(),
        ],
      ),
    );
  }
}

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({required this.monitor});

  final CameraMonitor monitor;

  @override
  Widget build(BuildContext context) {
    final pending = monitor.camera.id == 'pending';
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SectionTitle('Happening now'),
          Text(
            monitor.activity,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, height: 1.25),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RiskBadge(level: monitor.risk.name),
              InfoChip(label: 'People ${monitor.people}', icon: Icons.person_outline),
              if (monitor.battery != null)
                InfoChip(
                  label: '${monitor.battery}%${monitor.charging ? ' charging' : ''}',
                  icon: Icons.battery_std_outlined,
                ),
              if (monitor.cloudOffline)
                const InfoChip(label: 'ON DEVICE ONLY', icon: Icons.cloud_off, color: AppColors.warning),
            ],
          ),
          if (monitor.failure != null) ...[
            const SizedBox(height: 12),
            Text(monitor.failure!, style: const TextStyle(color: AppColors.critical)),
          ],
          if (monitor.ownerLiveAddress != null) ...[
            const SizedBox(height: 12),
            Text(
              'Owner live view: ${monitor.ownerLiveAddress}',
              style: const TextStyle(color: AppColors.muted, height: 1.3),
            ),
          ],
          const SizedBox(height: 18),
          PrimaryButton(
            label: pending
                ? 'Pair this phone'
                : monitor.monitoring
                    ? 'Stop recording incidents'
                    : 'Record incidents',
            onPressed: pending
                ? () => context.push('/camera/pair')
                : () => monitor.monitoring ? monitor.stop() : monitor.start(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: SecondaryButton(label: 'Flip', onPressed: monitor.flip)),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: monitor.dimmed ? 'Undim' : 'Dim',
                  onPressed: monitor.toggleDim,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: SecondaryButton(
                  label: 'Settings',
                  onPressed: () => context.push('/camera/settings'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SignOutButton extends ConsumerWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return TextButton(
      onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
      child: const Text('Sign out'),
    );
  }
}

class _LivePreview extends StatelessWidget {
  const _LivePreview({required this.controller});

  final CameraController controller;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CameraValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        if (!value.isInitialized) return const ColoredBox(color: Colors.black);
        try {
          return FittedBox(
            fit: BoxFit.cover,
            child: SizedBox(
              width: value.previewSize?.height ?? 1080,
              height: value.previewSize?.width ?? 1920,
              child: controller.buildPreview(),
            ),
          );
        } on CameraException {
          return const ColoredBox(color: Colors.black);
        }
      },
    );
  }
}

class CameraSettingsScreen extends ConsumerWidget {
  const CameraSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Camera settings')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SectionTitle('This phone'),
          const AppCard(
            child: Text(
              'The camera describes what it sees while this screen is open. '
              'Incidents are recorded only when something suspicious happens.',
              style: TextStyle(height: 1.4),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Camera'),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Pair this phone'),
                  subtitle: const Text('Scan a code from the dashboard'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => context.push('/camera/pair'),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Night schedule'),
                  subtitle: const Text('Arm monitoring from 8 PM to 6 AM'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => _saveNightSchedule(context, ref),
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Return to dashboard'),
                  trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                  onTap: () => ref.read(sessionControllerProvider.notifier).chooseMode(AppMode.dashboard),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SectionTitle('Signed in as ${session.user?.email ?? ''}'),
          SecondaryButton(
            label: 'Sign out',
            onPressed: () => ref.read(sessionControllerProvider.notifier).signOut(),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Disconnect camera',
            onPressed: () async {
              await ref.read(sessionControllerProvider.notifier).updateSettings(
                    session.settings.copyWith(clearCamera: true),
                  );
              if (context.mounted) context.go('/camera');
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveNightSchedule(BuildContext context, WidgetRef ref) async {
    final session = ref.read(sessionControllerProvider);
    final cameraId = session.settings.activeCameraId;
    final org = session.organization;
    if (cameraId == null || org == null) return;
    final database = ref.read(orgDatabaseProvider);
    final cameras = await database.watchCameras(org.id).first;
    final camera = cameras.cast<CameraDevice?>().firstWhere(
          (item) => item?.id == cameraId,
          orElse: () => null,
        );
    if (camera == null) return;
    await database.saveCamera(camera.copyWith(schedule: MonitoringSchedule.nights()));
    if (context.mounted) showAppMessage(context, 'Night schedule saved.');
  }
}
