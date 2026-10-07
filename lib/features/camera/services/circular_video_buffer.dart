class CapturedSegment {
  const CapturedSegment({
    required this.path,
    required this.startedAt,
    required this.endedAt,
  });

  final String path;
  final DateTime startedAt;
  final DateTime endedAt;
}

class ClipPlan {
  const ClipPlan({
    required this.segments,
    required this.eventStart,
    required this.eventEnd,
  });

  final List<CapturedSegment> segments;
  final DateTime eventStart;
  final DateTime eventEnd;
}

class CircularVideoBuffer {
  CircularVideoBuffer({
    this.preRoll = const Duration(seconds: 10),
    this.segmentLength = const Duration(seconds: 5),
  });

  final Duration preRoll;
  final Duration segmentLength;
  final List<CapturedSegment> _segments = [];

  List<CapturedSegment> get segments => List.unmodifiable(_segments);

  void add(CapturedSegment segment) {
    _segments.add(segment);
    _segments.sort((a, b) => a.startedAt.compareTo(b.startedAt));
    final newest = _segments.last.endedAt;
    _segments.removeWhere((item) => newest.difference(item.endedAt) > preRoll);
  }

  ClipPlan freeze({
    required DateTime trigger,
    required Duration postRoll,
    List<CapturedSegment> postSegments = const [],
  }) {
    final start = trigger.subtract(preRoll);
    final end = trigger.add(postRoll);
    final selected = [..._segments, ...postSegments].where((segment) {
      return segment.endedAt.isAfter(start) && segment.startedAt.isBefore(end);
    }).toList();
    return ClipPlan(segments: selected, eventStart: start, eventEnd: end);
  }
}

class CapturedFrame {
  const CapturedFrame({required this.bytes, required this.capturedAt});

  final List<int> bytes;
  final DateTime capturedAt;
}

class FrameRing {
  FrameRing({this.capacity = const Duration(seconds: 12)});

  final Duration capacity;
  final List<CapturedFrame> _frames = [];

  void add(CapturedFrame frame) {
    _frames.add(frame);
    final newest = frame.capturedAt;
    _frames.removeWhere((item) => newest.difference(item.capturedAt) > capacity);
  }

  List<CapturedFrame> between(DateTime start, DateTime end) {
    return _frames
        .where((frame) => !frame.capturedAt.isBefore(start) && !frame.capturedAt.isAfter(end))
        .toList();
  }

  void clear() => _frames.clear();
}
