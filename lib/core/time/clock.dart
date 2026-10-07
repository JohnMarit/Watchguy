abstract class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now().toUtc();
}

class FakeClock implements Clock {
  FakeClock(DateTime start) : _now = start.toUtc();

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration duration) {
    _now = _now.add(duration);
  }
}
