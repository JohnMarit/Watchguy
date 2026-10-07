import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../app/providers.dart';
import '../../../core/models/enums.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/common.dart';
import '../domain/zone_geometry.dart';

class ZoneEditorScreen extends ConsumerStatefulWidget {
  const ZoneEditorScreen({super.key, required this.cameraId});

  final String cameraId;

  @override
  ConsumerState<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends ConsumerState<ZoneEditorScreen> {
  final points = <NormPoint>[];
  var type = ZoneType.restricted;
  final name = TextEditingController(text: 'Restricted area');

  @override
  Widget build(BuildContext context) {
    final zones = ref.watch(orgDatabaseProvider);
    final orgId = ref.watch(sessionControllerProvider).organization?.id;
    return Scaffold(
      appBar: AppBar(title: const Text('Security zones')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text('Tap the frame to add corners. Coordinates are saved from 0 to 1, not as pixels.'),
          const SizedBox(height: 12),
          AspectRatio(
            aspectRatio: 3 / 4,
            child: LayoutBuilder(
              builder: (context, constraints) {
                return GestureDetector(
                  onTapDown: (details) {
                    setState(() {
                      points.add(NormPoint(
                        (details.localPosition.dx / constraints.maxWidth).clamp(0, 1).toDouble(),
                        (details.localPosition.dy / constraints.maxHeight).clamp(0, 1).toDouble(),
                      ));
                    });
                  },
                  child: CustomPaint(
                    painter: _ZonePainter(points),
                    child: const SizedBox.expand(),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          TextField(controller: name, decoration: const InputDecoration(labelText: 'Zone name')),
          const SizedBox(height: 8),
          DropdownButton<ZoneType>(
            value: type,
            dropdownColor: AppColors.surface,
            items: ZoneType.values
                .map((value) => DropdownMenuItem(value: value, child: Text(value.name)))
                .toList(),
            onChanged: (value) {
              if (value != null) setState(() => type = value);
            },
          ),
          const SizedBox(height: 12),
          PrimaryButton(
            label: 'Save zone',
            onPressed: points.length < 3 || orgId == null
                ? null
                : () async {
                    await zones.saveZone(SecurityZone(
                      id: const Uuid().v4(),
                      organizationId: orgId,
                      cameraId: widget.cameraId,
                      name: name.text.trim(),
                      type: type,
                      points: List.of(points),
                      createdAt: ref.read(clockProvider).now(),
                    ));
                    if (context.mounted) showAppMessage(context, 'Zone saved.');
                    setState(points.clear);
                  },
          ),
          TextButton(onPressed: () => setState(points.clear), child: const Text('Clear points')),
        ],
      ),
    );
  }
}

class _ZonePainter extends CustomPainter {
  _ZonePainter(this.points);

  final List<NormPoint> points;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = AppColors.surface,
    );
    final paint = Paint()
      ..color = AppColors.critical
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final offsets = points.map((point) => Offset(point.x * size.width, point.y * size.height)).toList();
    if (offsets.length > 1) {
      final path = Path()..moveTo(offsets.first.dx, offsets.first.dy);
      for (final offset in offsets.skip(1)) {
        path.lineTo(offset.dx, offset.dy);
      }
      if (offsets.length > 2) path.close();
      canvas.drawPath(path, paint);
    }
    for (final offset in offsets) {
      canvas.drawCircle(offset, 5, Paint()..color = AppColors.redBright);
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePainter oldDelegate) => oldDelegate.points != points;
}
