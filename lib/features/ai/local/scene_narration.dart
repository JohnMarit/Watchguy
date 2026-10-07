import 'object_detector.dart';

/// Label the motion detector uses when nothing has named the shape yet.
const movingObjectLabel = 'moving object';

/// Plain description of whatever is currently visible.
/// This is separate from incident recording: a quiet person or object is still said.
String describeScene({
  required List<Detection> detections,
  required double motionScore,
  bool blocked = false,
  bool restricted = false,
  String? zoneName,
}) {
  if (detections.isEmpty) {
    if (blocked) return 'The camera view is blocked.';
    if (motionScore >= 0.02) return 'Something is moving in view.';
    return 'Nothing is happening in view.';
  }

  final counts = <String, int>{};
  for (final detection in detections) {
    final name = spokenLabel(detection.label);
    counts[name] = (counts[name] ?? 0) + 1;
  }

  if (counts.length == 1 && counts.containsKey(movingObjectLabel)) {
    return 'Something is moving in view.';
  }

  final singlePerson = counts.length == 1 && counts['person'] == 1;
  final String sentence;
  if (singlePerson) {
    sentence = motionScore < 0.02 ? 'A person is standing in view.' : 'A person is moving in view.';
  } else {
    final phrases = counts.entries.map((entry) => _phrase(entry.key, entry.value)).toList();
    final total = counts.values.fold<int>(0, (sum, count) => sum + count);
    sentence = '${_join(phrases)} ${total == 1 ? 'is' : 'are'} in view.';
  }

  if (restricted && (counts['person'] ?? 0) > 0) {
    final where = zoneName == null || zoneName.isEmpty ? 'a restricted zone' : zoneName;
    return '$sentence Inside $where.';
  }
  return sentence;
}

String spokenLabel(String label) {
  final cleaned = label.trim().toLowerCase().replaceAll('_', ' ');
  return cleaned.isEmpty ? 'object' : cleaned;
}

String _phrase(String name, int count) {
  if (name == 'person') {
    if (count == 1) return 'A person';
    if (count == 2) return 'Two people';
    return '$count people';
  }
  if (count == 1) return 'A $name';
  if (count == 2) return 'Two ${_plural(name)}';
  return '$count ${_plural(name)}';
}

String _plural(String name) {
  if (name.endsWith('s') || name.endsWith('x') || name.endsWith('ch') || name.endsWith('sh')) {
    return '${name}es';
  }
  if (name.endsWith('y') && name.length > 1 && !'aeiou'.contains(name[name.length - 2])) {
    return '${name.substring(0, name.length - 1)}ies';
  }
  return '${name}s';
}

String _join(List<String> phrases) {
  if (phrases.length == 1) return phrases.single;
  if (phrases.length == 2) return '${phrases[0]} and ${phrases[1][0].toLowerCase()}${phrases[1].substring(1)}';
  final head = phrases.sublist(0, phrases.length - 1).join(', ');
  final last = phrases.last;
  return '$head, and ${last[0].toLowerCase()}${last.substring(1)}';
}
