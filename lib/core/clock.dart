/// Injectable wall clock. Production code must never call [DateTime.now]
/// directly (see CLAUDE.md) — depend on [Clock] so tests can fake time.
abstract interface class Clock {
  DateTime now();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Test clock with manual control.
class FixedClock implements Clock {
  FixedClock(this._now);

  DateTime _now;

  @override
  DateTime now() => _now;

  void advance(Duration d) => _now = _now.add(d);

  set time(DateTime t) => _now = t;
}
