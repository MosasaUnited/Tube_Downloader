import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';

/// Removes the FSI/PDI isolates to check the visible text.
String _plain(String s) => s.replaceAll('\u2068', '').replaceAll('\u2069', '');

void main() {
  test('every value is bidi-isolated for Arabic layouts', () {
    for (final s in [
      formatBytes(1),
      formatSpeed(1),
      formatPercent(0.5),
      formatDuration(Duration.zero),
    ]) {
      expect(s.startsWith('\u2068'), isTrue);
      expect(s.endsWith('\u2069'), isTrue);
    }
  });

  test('bytes', () {
    expect(_plain(formatBytes(512)), '512 B');
    expect(_plain(formatBytes(14 * 1024)), '14 KB');
    expect(_plain(formatBytes((9.6 * 1024 * 1024).round())), '9.6 MB');
    expect(_plain(formatBytes(245 * 1024 * 1024)), '245 MB');
    expect(_plain(formatBytes((2.1 * 1024 * 1024 * 1024).round())), '2.1 GB');
  });

  test('speed and percent', () {
    expect(_plain(formatSpeed(18.4 * 1024 * 1024)), '18.4 MB/s');
    expect(_plain(formatSpeed(0.6 * 1024 * 1024)), '0.6 MB/s');
    expect(_plain(formatSpeed(0.4 * 1024 * 1024)), '410 KB/s');
    expect(_plain(formatPercent(0.684)), '68%');
    expect(_plain(formatPercent(1.4)), '100%');
  });

  test('durations', () {
    expect(
      _plain(formatDuration(const Duration(minutes: 18, seconds: 42))),
      '18:42',
    );
    expect(
      _plain(formatDuration(const Duration(hours: 1, minutes: 14))),
      '1:14:00',
    );
    expect(_plain(formatDuration(const Duration(seconds: 38))), '0:38');
  });
}
