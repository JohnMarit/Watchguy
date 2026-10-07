import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/providers.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../camera/domain/camera_device.dart';
import '../../incidents/domain/incident.dart';
import '../../live_stream/data/local_camera_mirror.dart';
import '../../live_stream/presentation/local_frame_view.dart';
import '../domain/dashboard_summary.dart';

final camerasProvider = StreamProvider<List<CameraDevice>>((ref) {
  final org = ref.watch(sessionControllerProvider).organization;
  if (org == null) return const Stream.empty();
  return ref.watch(orgDatabaseProvider).watchCameras(org.id);
});

final incidentsProvider = StreamProvider<List<Incident>>((ref) {
  final org = ref.watch(sessionControllerProvider).organization;
  if (org == null) return const Stream.empty();
  return ref.watch(orgDatabaseProvider).watchIncidents(org.id);
});

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  var index = 0;
  LocalCameraMirror? mirror;

  @override
  void initState() {
    super.initState();
    Future.microtask(_startMirror);
  }

  void _startMirror() {
    final org = ref.read(sessionControllerProvider).organization;
    if (org == null || mirror != null) return;
    final created = LocalCameraMirror(
      database: ref.read(orgDatabaseProvider),
      organizationId: org.id,
    );
    created.start();
    mirror = created;
  }

  @override
  void dispose() {
    mirror?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _startMirror();
    const pages = [_HomeTab(), _CamerasTab(), _IncidentsTab(), _SettingsTab()];
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppGradients.header),
        child: SafeArea(child: pages[index]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (value) => setState(() => index = value),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.shield_outlined), label: 'Overview'),
          NavigationDestination(icon: Icon(Icons.videocam_outlined), label: 'Cameras'),
          NavigationDestination(icon: Icon(Icons.warning_amber_rounded), label: 'Incidents'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), label: 'Settings'),
        ],
      ),
    );
  }
}

class _HomeTab extends ConsumerWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final cameras = ref.watch(camerasProvider).value ?? const <CameraDevice>[];
    final incidents = ref.watch(incidentsProvider).value ?? const <Incident>[];
    final now = ref.watch(clockProvider).now();
    final summary = DashboardSummary.fromCameras(cameras, now);
    final ordered = [...cameras]..sort((a, b) => compareCamerasByPriority(a, b, now));
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        ScreenTitle(
          session.organization?.name ?? 'Organization',
          subtitle: session.user?.email,
          trailing: IconButton(
            onPressed: () => context.push('/dashboard/incidents'),
            icon: const Icon(Icons.notifications_none),
          ),
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            MetricBlock(value: '${summary.online}', label: 'Online'),
            const SizedBox(width: 10),
            MetricBlock(value: '${summary.alerts}', label: 'Alerts', accent: summary.alerts > 0),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            MetricBlock(value: '${summary.cameras}', label: 'Cameras'),
            const SizedBox(width: 10),
            MetricBlock(value: '${summary.offline}', label: 'Offline'),
          ],
        ),
        const SizedBox(height: 28),
        SectionTitle(
          'Needs attention',
          action: TextButton(
            onPressed: () => context.push('/dashboard/grid'),
            child: const Text('All cameras'),
          ),
        ),
        if (ordered.isEmpty)
          const AppCard(child: Text('No cameras yet. Add one from the Cameras tab.'))
        else
          ...ordered.take(3).map(
                (camera) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CameraCard(camera: camera, now: now),
                ),
              ),
        const SizedBox(height: 20),
        const SectionTitle('Recent incidents'),
        if (incidents.isEmpty)
          const AppCard(child: Text('Nothing suspicious has been recorded yet.'))
        else
          ...incidents.take(4).map(
                (incident) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _IncidentCard(incident: incident),
                ),
              ),
      ],
    );
  }
}

class _CamerasTab extends ConsumerWidget {
  const _CamerasTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameras = ref.watch(camerasProvider).value ?? const <CameraDevice>[];
    final now = ref.watch(clockProvider).now();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        ScreenTitle(
          'Cameras',
          subtitle: '${cameras.length} paired',
          trailing: TextButton(
            onPressed: () => context.push('/dashboard/pair'),
            child: const Text('Add'),
          ),
        ),
        const SizedBox(height: 20),
        if (cameras.isEmpty)
          const AppCard(
            child: Text(
              'Pair a phone to turn it into a camera. It shows up here once it is online.',
              style: TextStyle(height: 1.4),
            ),
          )
        else
          ...cameras.map(
            (camera) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _CameraCard(camera: camera, now: now),
            ),
          ),
        const SizedBox(height: 10),
        SecondaryButton(
          label: 'Multi-camera view',
          onPressed: () => context.push('/dashboard/grid'),
        ),
      ],
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera, required this.now});

  final CameraDevice camera;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final online = isCameraOnline(camera.heartbeat, now);
    final level = camera.heartbeat.riskLevel;
    final highlight = online && (level == RiskLevel.high || level == RiskLevel.critical);
    final flags = cameraHealthFlags(camera, now);
    return AppCard(
      highlight: highlight,
      onTap: () => context.push('/dashboard/cameras/${camera.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  camera.name.toUpperCase(),
                  style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 0.3),
                ),
              ),
              StatusDot(
                color: online ? AppColors.online : AppColors.muted,
                label: online ? 'LIVE' : 'OFFLINE',
              ),
            ],
          ),
          if (camera.location.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(camera.location, style: const TextStyle(color: AppColors.muted)),
          ],
          const SizedBox(height: 12),
          Text(
            camera.heartbeat.activity.isEmpty
                ? 'Waiting for the first update.'
                : camera.heartbeat.activity,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, height: 1.3),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RiskBadge(level: level.name),
              InfoChip(label: 'People ${camera.heartbeat.peopleCount}', icon: Icons.person_outline),
              for (final flag in flags)
                InfoChip(label: flag, icon: Icons.error_outline, color: AppColors.warning),
            ],
          ),
        ],
      ),
    );
  }
}

class _IncidentsTab extends ConsumerStatefulWidget {
  const _IncidentsTab();

  @override
  ConsumerState<_IncidentsTab> createState() => _IncidentsTabState();
}

class _IncidentsTabState extends ConsumerState<_IncidentsTab> {
  String filter = 'all';

  @override
  Widget build(BuildContext context) {
    final incidents = ref.watch(incidentsProvider).value ?? const <Incident>[];
    final visible = incidents.where((incident) {
      if (filter == 'all') return true;
      return incident.riskLevel.name == filter;
    }).toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        ScreenTitle('Incidents', subtitle: '${incidents.length} recorded'),
        const SizedBox(height: 16),
        Wrap(
          spacing: 8,
          children: ['all', 'critical', 'high', 'medium', 'low'].map((value) {
            return ChoiceChip(
              label: Text(value.toUpperCase()),
              selected: filter == value,
              onSelected: (_) => setState(() => filter = value),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        if (visible.isEmpty)
          const AppCard(child: Text('Nothing in this view.'))
        else
          ...visible.map(
            (incident) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _IncidentCard(incident: incident),
            ),
          ),
      ],
    );
  }
}

class _IncidentCard extends StatelessWidget {
  const _IncidentCard({required this.incident});

  final Incident incident;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat.jm().format(incident.createdAt.toLocal());
    return AppCard(
      onTap: () => context.push('/dashboard/incidents/${incident.id}'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              RiskBadge(level: incident.riskLevel.name),
              const Spacer(),
              Text(time, style: const TextStyle(color: AppColors.muted)),
            ],
          ),
          const SizedBox(height: 10),
          Text(incident.cameraName, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(incident.description, style: const TextStyle(height: 1.3)),
        ],
      ),
    );
  }
}

class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionControllerProvider);
    final settings = session.settings;
    final controller = ref.read(sessionControllerProvider.notifier);
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
      children: [
        ScreenTitle('Settings', subtitle: session.user?.email),
        const SizedBox(height: 20),
        const SectionTitle('Organization'),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.organization?.name ?? 'Organization',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(height: 4),
              const Text('You are the owner', style: TextStyle(color: AppColors.muted)),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Video quality'),
        SegmentedButton<DataSaverMode>(
          segments: const [
            ButtonSegment(value: DataSaverMode.lowData, label: Text('Low')),
            ButtonSegment(value: DataSaverMode.balanced, label: Text('Balanced')),
            ButtonSegment(value: DataSaverMode.highQuality, label: Text('High')),
          ],
          selected: {settings.dataSaver},
          onSelectionChanged: (selection) {
            controller.updateSettings(settings.copyWith(dataSaver: selection.first));
          },
        ),
        const SizedBox(height: 24),
        const SectionTitle('Alerts'),
        AppCard(
          child: Column(
            children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                value: settings.notificationsEnabled,
                title: const Text('Security alerts'),
                subtitle: const Text('High and critical incidents only'),
                onChanged: (value) {
                  controller.updateSettings(settings.copyWith(notificationsEnabled: value));
                },
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Use this phone as a camera'),
                trailing: const Icon(Icons.chevron_right, color: AppColors.muted),
                onTap: () => controller.chooseMode(AppMode.camera),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Account'),
        SecondaryButton(label: 'Sign out', onPressed: controller.signOut),
        const SizedBox(height: 8),
        const Text(
          'Sign out to open a different account on this phone.',
          style: TextStyle(color: AppColors.muted, height: 1.4),
        ),
      ],
    );
  }
}

class CameraDetailScreen extends ConsumerWidget {
  const CameraDetailScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cameras = ref.watch(camerasProvider).value ?? const <CameraDevice>[];
    final camera = cameras.where((item) => item.id == cameraId).firstOrNull;
    if (camera == null) {
      return const Scaffold(body: Center(child: Text('This camera is no longer available.')));
    }
    final now = ref.watch(clockProvider).now();
    final online = isCameraOnline(camera.heartbeat, now);
    final updated = now.difference(camera.heartbeat.monitoredAt);
    return Scaffold(
      appBar: AppBar(title: Text(camera.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: SizedBox(
              height: 260,
              child: LocalFrameView(cameraId: camera.id, cameraName: camera.name),
            ),
          ),
          const SizedBox(height: 20),
          const SectionTitle('Happening now'),
          Text(
            camera.heartbeat.activity.isEmpty
                ? 'Waiting for the first update.'
                : camera.heartbeat.activity,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700, height: 1.3),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              RiskBadge(level: camera.heartbeat.riskLevel.name),
              InfoChip(
                label: online ? 'ONLINE' : 'OFFLINE',
                icon: Icons.circle,
                color: online ? AppColors.online : AppColors.muted,
              ),
              InfoChip(label: 'People ${camera.heartbeat.peopleCount}', icon: Icons.person_outline),
              InfoChip(label: '${updated.inSeconds}s ago', icon: Icons.schedule),
            ],
          ),
          const SizedBox(height: 28),
          PrimaryButton(
            label: 'Watch live',
            onPressed: () => context.push('/dashboard/cameras/$cameraId/live'),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'View events',
            onPressed: () => context.push('/dashboard/incidents'),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: camera.mutedAlerts ? 'Unmute alerts' : 'Mute alerts',
            onPressed: () => ref
                .read(orgDatabaseProvider)
                .saveCamera(camera.copyWith(mutedAlerts: !camera.mutedAlerts)),
          ),
          const SizedBox(height: 10),
          SecondaryButton(
            label: 'Camera zones',
            onPressed: () => context.push('/dashboard/cameras/$cameraId/zones'),
          ),
        ],
      ),
    );
  }
}
