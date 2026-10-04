import 'dart:async';
import 'dart:math';

import 'package:clock/clock.dart';

/// Paces calls to YouTube: one resolve at a time, at least [minSpacing]
/// apart, extra jitter between playlist items, and a global cooldown after a
/// rate limit. Resolves — not byte transfers — are what trigger 429s.
class ResolveGate {
  ResolveGate({
    Clock? clock,
    Random? random,
    Future<void> Function(Duration)? delay,
    this.minSpacing = const Duration(milliseconds: 1500),
  }) : _clock = clock ?? const Clock(),
       _random = random ?? Random(),
       _delay = delay ?? Future<void>.delayed;

  final Clock _clock;
  final Random _random;
  final Future<void> Function(Duration) _delay;
  final Duration minSpacing;

  Future<void> _tail = Future<void>.value();
  DateTime? _lastStart;
  DateTime? _cooldownUntil;

  /// When the current rate-limit cooldown ends (null = none).
  DateTime? get cooldownUntil => _cooldownUntil;

  void cooldown(Duration duration) {
    final until = _clock.now().add(duration);
    if (_cooldownUntil == null || until.isAfter(_cooldownUntil!)) {
      _cooldownUntil = until;
    }
  }

  /// Runs [action] when the gate allows. [playlistItem] adds 1–3 s of jitter.
  Future<T> run<T>(Future<T> Function() action, {bool playlistItem = false}) {
    final previous = _tail;
    final done = Completer<void>();
    _tail = done.future;
    return () async {
      await previous;
      try {
        await _waitTurn(playlistItem);
        return await action();
      } finally {
        done.complete();
      }
    }();
  }

  Future<void> _waitTurn(bool playlistItem) async {
    final now = _clock.now();
    var readyAt = now;
    if (_lastStart != null) {
      var spacing = minSpacing;
      if (playlistItem) {
        spacing += Duration(milliseconds: 1000 + _random.nextInt(2000));
      }
      final next = _lastStart!.add(spacing);
      if (next.isAfter(readyAt)) readyAt = next;
    }
    if (_cooldownUntil != null && _cooldownUntil!.isAfter(readyAt)) {
      readyAt = _cooldownUntil!;
    }
    final wait = readyAt.difference(now);
    if (wait > Duration.zero) await _delay(wait);
    _lastStart = _clock.now();
  }
}
