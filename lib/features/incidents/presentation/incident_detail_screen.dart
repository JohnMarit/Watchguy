import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:video_player/video_player.dart';

import '../../../app/providers.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../domain/incident.dart';

class IncidentListScreen extends ConsumerWidget {
  const IncidentListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider).value ?? const <Incident>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Incidents')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (incidents.isEmpty)
            const Text('No incidents yet.', style: TextStyle(color: AppColors.muted))
          else
            ...incidents.map(
              (incident) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: AppCard(
                  onTap: () => context.push('/dashboard/incidents/${incident.id}'),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(incident.cameraName, style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 6),
                      Text(incident.description),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class IncidentDetailScreen extends ConsumerWidget {
  const IncidentDetailScreen({super.key, required this.incidentId});

  final String incidentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final incidents = ref.watch(incidentsProvider).value ?? const <Incident>[];
    final incident = incidents.cast<Incident?>().firstWhere(
          (item) => item?.id == incidentId,
          orElse: () => null,
        );
    if (incident == null) {
      return const Scaffold(body: Center(child: Text('Incident not found.')));
    }
    return Scaffold(
      appBar: AppBar(title: Text(incident.cameraName)),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          _ClipPlayer(path: incident.localClipPath, videoUrl: incident.videoUrl),
          const SizedBox(height: 16),
          RiskBadge(level: incident.riskLevel.name),
          const SizedBox(height: 12),
          Text(incident.description, style: const TextStyle(fontSize: 20, height: 1.35)),
          const SizedBox(height: 12),
          Text(DateFormat.yMMMd().add_jm().format(incident.createdAt.toLocal()), style: const TextStyle(color: AppColors.muted)),
          Text('Score ${incident.riskScore}', style: const TextStyle(color: AppColors.muted)),
          if (incident.zoneName != null) Text('Zone: ${incident.zoneName}'),
          const SizedBox(height: 16),
          ...incident.observations.map((item) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $item'),
              )),
          const SizedBox(height: 16),
          PrimaryButton(
            label: 'Confirmed event',
            onPressed: () => _review(ref, incident, ReviewState.confirmed),
          ),
          const SizedBox(height: 8),
          SecondaryButton(label: 'False alarm', onPressed: () => _review(ref, incident, ReviewState.falseAlarm)),
          const SizedBox(height: 8),
          SecondaryButton(label: 'Unsure', onPressed: () => _review(ref, incident, ReviewState.unsure)),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              await ref.read(orgDatabaseProvider).deleteIncident(incident.organizationId, incident.id);
              final path = incident.localClipPath;
              if (path != null && Directory(path).existsSync()) Directory(path).deleteSync(recursive: true);
              if (context.mounted) Navigator.of(context).pop();
            },
            child: const Text('Delete incident and video', style: TextStyle(color: AppColors.critical)),
          ),
        ],
      ),
    );
  }

  Future<void> _review(WidgetRef ref, Incident incident, ReviewState review) {
    return ref.read(orgDatabaseProvider).saveIncident(
          incident.copyWith(reviewState: review, status: IncidentStatus.reviewed),
        );
  }
}

class _ClipPlayer extends StatefulWidget {
  const _ClipPlayer({required this.path, required this.videoUrl});

  final String? path;
  final String? videoUrl;

  @override
  State<_ClipPlayer> createState() => _ClipPlayerState();
}

class _ClipPlayerState extends State<_ClipPlayer> {
  List<File> frames = const [];
  var index = 0;
  VideoPlayerController? video;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final path = widget.path;
    if (path != null && Directory(path).existsSync()) {
      final files = Directory(path)
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.jpg'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));
      final videos = Directory(path).listSync().whereType<File>().where((file) => file.path.endsWith('.mp4'));
      if (videos.isNotEmpty) {
        video = VideoPlayerController.file(videos.first);
        await video!.initialize();
        await video!.play();
      }
      if (mounted) setState(() => frames = files);
      _advance();
    }
  }

  Future<void> _advance() async {
    while (mounted && frames.length > 1 && video == null) {
      await Future<void>.delayed(const Duration(milliseconds: 125));
      if (!mounted) return;
      setState(() => index = (index + 1) % frames.length);
    }
  }

  @override
  void dispose() {
    video?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (video != null && video!.value.isInitialized) {
      return AspectRatio(aspectRatio: video!.value.aspectRatio, child: VideoPlayer(video!));
    }
    if (frames.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(20)),
        child: const Text('Clip is still on the camera phone.', style: TextStyle(color: AppColors.muted)),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Image.file(frames[index], height: 220, width: double.infinity, fit: BoxFit.cover),
    );
  }
}
