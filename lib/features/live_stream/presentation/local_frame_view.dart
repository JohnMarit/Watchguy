import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../../../core/theme/app_colors.dart';
import '../data/local_live_relay.dart';

class LocalFrameView extends StatefulWidget {
  const LocalFrameView({
    super.key,
    required this.cameraId,
    this.cameraName = '',
    this.compact = false,
  });

  final String cameraId;
  final String cameraName;

  /// Thumbnail mode hides the narration line so grids stay readable.
  final bool compact;

  @override
  State<LocalFrameView> createState() => _LocalFrameViewState();
}

class _LocalFrameViewState extends State<LocalFrameView> {
  final directory = LocalLiveDirectory.instance;
  Uint8List? bytes;
  String activity = '';
  Timer? timer;
  var fetching = false;

  @override
  void initState() {
    super.initState();
    directory.start();
    directory.addListener(_schedule);
    timer = Timer.periodic(const Duration(milliseconds: 400), (_) => _pull());
    _pull();
  }

  @override
  void dispose() {
    timer?.cancel();
    directory.removeListener(_schedule);
    super.dispose();
  }

  void _schedule() {
    if (mounted) _pull();
  }

  Future<void> _pull() async {
    final feed = directory.feedFor(widget.cameraId);
    if (!mounted) return;
    if (feed == null) {
      if (activity.isNotEmpty) setState(() => activity = '');
      return;
    }
    if (feed.activity != activity) {
      setState(() => activity = feed.activity);
    }
    if (fetching) return;
    fetching = true;
    try {
      final response = await http.get(feed.frameUri).timeout(const Duration(seconds: 2));
      if (!mounted) return;
      if (response.statusCode == 200 && response.bodyBytes.isNotEmpty) {
        setState(() => bytes = response.bodyBytes);
      }
    } catch (_) {
      // The camera phone may be between frames or off the network.
    } finally {
      fetching = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final image = bytes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ColoredBox(
            color: Colors.black,
            child: image == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        widget.compact ? 'Offline' : 'Waiting for this camera on the same Wi-Fi.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.muted, height: 1.4),
                      ),
                    ),
                  )
                : Image.memory(
                    image,
                    fit: widget.compact ? BoxFit.cover : BoxFit.contain,
                    gaplessPlayback: true,
                  ),
          ),
        ),
        if (activity.isNotEmpty && !widget.compact)
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            child: Text(activity, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700, height: 1.3)),
          ),
      ],
    );
  }
}
