import 'dart:math';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/domain/services/backoff_policy.dart';
import 'package:tube_downloader/core/download_core/domain/services/progress_throttler.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';

void main() {
  group('BackoffPolicy', () {
    test('network retries: 2 s, 8 s, 30 s, then give up', () {
      final policy = BackoffPolicy();
      expect(
        [for (var i = 0; i < 4; i++) policy.networkRetry(i)],
        [
          const Duration(seconds: 2),
          const Duration(seconds: 8),
          const Duration(seconds: 30),
          null,
        ],
      );
    });

    test(
      'rate-limit cooldown doubles from 30 s, caps at 15 min, ±20 % jitter',
      () {
        final policy = BackoffPolicy(random: Random(7));
        for (final (strike, base) in [
          (1, 30),
          (2, 60),
          (3, 120),
          (6, 900),
          (9, 900),
        ]) {
          final d = policy.rateLimitCooldown(strike).inMilliseconds;
          expect(
            d,
            inInclusiveRange(base * 800, base * 1200),
            reason: 'strike $strike',
          );
        }
      },
    );
  });

  group('SpeedMeter / ProgressThrottler', () {
    test('speed is smoothed and gives an ETA', () {
      final meter = SpeedMeter();
      final t0 = DateTime(2026);
      meter.sample(0, t0);
      meter.sample(1000000, t0.add(const Duration(seconds: 1)));
      expect(meter.bytesPerSecond, 1000000);
      meter.sample(
        1500000,
        t0.add(const Duration(seconds: 2)),
      ); // dip to 0.5 MB/s
      expect(
        meter.bytesPerSecond,
        closeTo(850000, 1),
        reason: '0.3·0.5 + 0.7·1.0 MB/s',
      );
      expect(meter.eta(1500000, 3200000), const Duration(seconds: 2));
    });

    test(
      'at most one update per 250 ms unless progress jumps ≥1 % or is final',
      () {
        final throttler = ProgressThrottler();
        final t0 = DateTime(2026);
        bool at(int ms, int done, {bool isFinal = false}) =>
            throttler.shouldEmit(
              done: done,
              total: 10000,
              now: t0.add(Duration(milliseconds: ms)),
              isFinal: isFinal,
            );
        expect(at(0, 10), isTrue);
        expect(at(100, 20), isFalse);
        expect(at(120, 200), isTrue, reason: 'jumped 1.9 %');
        expect(at(200, 210), isFalse);
        expect(at(380, 215), isTrue, reason: '250 ms passed');
        expect(at(390, 216, isFinal: true), isTrue);
      },
    );
  });

  group('ResolveGate', () {
    test('serializes resolves at least 1.5 s apart and honours a cooldown', () {
      fakeAsync((async) {
        final gate = ResolveGate(
          clock: async.getClock(DateTime(2026)),
          random: Random(1),
        );
        final started = <Duration>[];
        final start = async.elapsed;
        Future<void> job() async => started.add(async.elapsed - start);

        gate.run(job);
        gate.run(job);
        async.elapse(const Duration(seconds: 10));
        gate.cooldown(const Duration(seconds: 30));
        gate.run(job);
        async.elapse(const Duration(minutes: 1));

        expect(started[0], Duration.zero);
        expect(started[1], const Duration(milliseconds: 1500));
        expect(
          started[2],
          const Duration(seconds: 40),
          reason: 'waited out the 30 s cooldown from t=10 s',
        );
      });
    });

    test('playlist items get 1–3 s of extra jitter', () {
      fakeAsync((async) {
        final gate = ResolveGate(
          clock: async.getClock(DateTime(2026)),
          random: Random(3),
        );
        final started = <Duration>[];
        Future<void> job() async => started.add(async.elapsed);
        gate.run(job, playlistItem: true);
        gate.run(job, playlistItem: true);
        async.elapse(const Duration(seconds: 10));
        final gap = started[1] - started[0];
        expect(gap.inMilliseconds, inInclusiveRange(2500, 4500));
      });
    });

    test('a failing action releases the gate', () {
      fakeAsync((async) {
        final gate = ResolveGate(clock: async.getClock(DateTime(2026)));
        Object? error;
        gate
            .run<void>(() async => throw StateError('boom'))
            .catchError((Object e) => error = e);
        var ran = false;
        gate.run(() async => ran = true);
        async.elapse(const Duration(seconds: 5));
        expect(error, isA<StateError>());
        expect(ran, isTrue);
      });
    });
  });
}
