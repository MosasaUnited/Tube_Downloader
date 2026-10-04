/// Keeps the operating system from throttling the app while downloads run
/// (macOS App Nap slows timers, network and FFmpeg of a background app).
/// The queue begins it when the first job starts and ends it when the last
/// one finishes.
abstract interface class ActivityAssertion {
  Future<void> begin();
  Future<void> end();
}

/// Platforms (and tests) with nothing to assert.
class NoActivityAssertion implements ActivityAssertion {
  const NoActivityAssertion();

  @override
  Future<void> begin() async {}

  @override
  Future<void> end() async {}
}
