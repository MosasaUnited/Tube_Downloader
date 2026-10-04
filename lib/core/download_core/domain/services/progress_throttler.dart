/// Smoothed transfer speed: an exponentially weighted moving average over
/// samples, so the ETA doesn't jump with every chunk.
class SpeedMeter {
  SpeedMeter({this.alpha = 0.3});

  final double alpha;
  double _bytesPerSecond = 0;
  int? _lastBytes;
  DateTime? _lastAt;

  double get bytesPerSecond => _bytesPerSecond;

  /// Feeds the running byte count at [now]; returns the smoothed speed.
  double sample(int bytes, DateTime now) {
    final lastBytes = _lastBytes;
    final lastAt = _lastAt;
    _lastBytes = bytes;
    _lastAt = now;
    if (lastBytes == null || lastAt == null) return _bytesPerSecond;
    final seconds = now.difference(lastAt).inMicroseconds / 1e6;
    if (seconds <= 0) return _bytesPerSecond;
    final instant = (bytes - lastBytes) / seconds;
    _bytesPerSecond = _bytesPerSecond == 0
        ? instant
        : alpha * instant + (1 - alpha) * _bytesPerSecond;
    return _bytesPerSecond;
  }

  /// Remaining time at the current speed; null when unknown.
  Duration? eta(int done, int? total) {
    if (total == null || _bytesPerSecond <= 0 || done >= total) return null;
    return Duration(
      milliseconds: ((total - done) / _bytesPerSecond * 1000).round(),
    );
  }

  void reset() {
    _bytesPerSecond = 0;
    _lastBytes = null;
    _lastAt = null;
  }
}

/// Rate-limits progress updates to the UI (performance skill): at most one per
/// [interval], unless progress moved by [minFraction] or it is final.
class ProgressThrottler {
  ProgressThrottler({
    this.interval = const Duration(milliseconds: 250),
    this.minFraction = 0.01,
  });

  final Duration interval;
  final double minFraction;
  DateTime? _lastAt;
  double _lastFraction = 0;

  bool shouldEmit({
    required int done,
    required int? total,
    required DateTime now,
    bool isFinal = false,
  }) {
    final fraction = total == null || total == 0 ? 0.0 : done / total;
    final due = _lastAt == null || now.difference(_lastAt!) >= interval;
    final jumped = (fraction - _lastFraction).abs() >= minFraction;
    if (!isFinal && !due && !jumped) return false;
    _lastAt = now;
    _lastFraction = fraction;
    return true;
  }
}
