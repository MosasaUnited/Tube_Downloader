import 'dart:math';

/// Retry timing for the queue (docs/spike/phase0.md decision log).
class BackoffPolicy {
  BackoffPolicy({
    Random? random,
    this.networkRetryDelays = defaultNetworkRetryDelays,
  }) : _random = random ?? Random();

  final Random _random;

  /// Waits before retrying a task after a network-type failure (tests inject
  /// shorter ones).
  final List<Duration> networkRetryDelays;

  static const defaultNetworkRetryDelays = [
    Duration(seconds: 2),
    Duration(seconds: 8),
    Duration(seconds: 30),
  ];

  /// Consecutive rate limits after which a task fails instead of waiting.
  static const maxRateLimitStrikes = 5;

  static const _rateLimitBase = Duration(seconds: 30);
  static const _rateLimitCap = Duration(minutes: 15);

  /// The delay before network retry number [failuresSoFar] + 1, or null when
  /// the retries are used up and the task should fail.
  Duration? networkRetry(int failuresSoFar) =>
      failuresSoFar < networkRetryDelays.length
      ? networkRetryDelays[failuresSoFar]
      : null;

  /// Global cooldown after the [strike]-th consecutive rate limit (1-based):
  /// 30 s · 2^(strike-1), capped at 15 min, ±20 % jitter so parallel clients
  /// don't retry in lockstep.
  Duration rateLimitCooldown(int strike) {
    final exp = min(strike - 1, 10);
    final base = _rateLimitBase * pow(2, exp).toInt();
    final capped = base > _rateLimitCap ? _rateLimitCap : base;
    final jitter = 0.8 + _random.nextDouble() * 0.4;
    return Duration(milliseconds: (capped.inMilliseconds * jitter).round());
  }
}
