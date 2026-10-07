String writeTime(DateTime value) => value.toUtc().toIso8601String();

DateTime parseTime(Object? value) {
  if (value == null) return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
  if (value is DateTime) return value.toUtc();
  if (value is String) return DateTime.parse(value).toUtc();
  final dynamic stamp = value;
  try {
    final converted = stamp.toDate();
    if (converted is DateTime) return converted.toUtc();
  } catch (_) {}
  return DateTime.fromMillisecondsSinceEpoch(0, isUtc: true);
}
