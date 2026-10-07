import 'object_detector.dart';

class ObjectTracker {
  ObjectTracker({this.iouThreshold = 0.3, this.maxMissed = 5});

  final double iouThreshold;
  final int maxMissed;
  final List<Track> _tracks = [];
  int _nextId = 1;

  List<Track> get tracks => List.unmodifiable(_tracks);

  List<Track> update(List<Detection> detections, DateTime now) {
    final unmatchedTracks = List<Track>.from(_tracks);
    final matched = <Track>{};

    for (final detection in detections) {
      Track? best;
      var bestIou = iouThreshold;
      for (final track in unmatchedTracks) {
        if (track.label != detection.label) continue;
        final score = track.box.iou(detection.box);
        if (score >= bestIou) {
          best = track;
          bestIou = score;
        }
      }
      if (best == null) {
        final created = Track(
          id: 't${_nextId++}',
          label: detection.label,
          box: detection.box,
          firstSeen: now,
          lastSeen: now,
          confidence: detection.confidence,
        );
        _tracks.add(created);
        matched.add(created);
      } else {
        best
          ..box = detection.box
          ..lastSeen = now
          ..confidence = detection.confidence
          ..missed = 0;
        unmatchedTracks.remove(best);
        matched.add(best);
      }
    }

    for (final track in List<Track>.from(_tracks)) {
      if (matched.contains(track)) continue;
      track.missed += 1;
      if (track.missed > maxMissed) _tracks.remove(track);
    }
    return tracks;
  }
}
