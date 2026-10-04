/// User-facing numbers: sizes, speeds, percentages, durations.
///
/// Technical values keep Western digits and Latin units in both languages
/// (the convention of Arabic system UIs for file sizes and speeds). Every result
/// is wrapped in Unicode bidi isolates (FSI … PDI) so "245 MB" or "1:14:00"
/// can never be reordered inside an Arabic sentence (rtl-a11y skill). This file
/// is the only place numbers are formatted by hand (review-gate).
library;

const _fsi = '\u2068';
const _pdi = '\u2069';

String _isolate(String s) => '$_fsi$s$_pdi';

const _kb = 1024;
const _mb = 1024 * 1024;
const _gb = 1024 * 1024 * 1024;

/// 512 B · 14 KB · 9.6 MB · 245 MB · 2.1 GB
String formatBytes(int bytes) => _isolate(_bytes(bytes));

/// 18.4 MB/s · 0.6 MB/s · 410 KB/s — speeds keep one decimal in the MB range
/// (the design shows "18.4 MB/s"), unlike sizes.
String formatSpeed(double bytesPerSecond) {
  if (bytesPerSecond < _mb / 2) {
    return _isolate('${(bytesPerSecond / _kb).round()} KB/s');
  }
  return _isolate('${(bytesPerSecond / _mb).toStringAsFixed(1)} MB/s');
}

/// 0.684 → 68%
String formatPercent(double fraction) =>
    _isolate('${(fraction.clamp(0, 1) * 100).floor()}%');

/// 18:42 · 1:14:00 (leading hour only when there is one)
String formatDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  final s = d.inSeconds.remainder(60);
  String two(int v) => v.toString().padLeft(2, '0');
  return _isolate(h > 0 ? '$h:${two(m)}:${two(s)}' : '$m:${two(s)}');
}

String _bytes(int bytes) {
  if (bytes < _kb) return '$bytes B';
  if (bytes < _mb) return '${(bytes / _kb).round()} KB';
  if (bytes < _gb) return '${_trim(bytes / _mb)} MB';
  return '${(bytes / _gb).toStringAsFixed(1)} GB';
}

/// One decimal below 10 ("9.6 MB"), none above ("245 MB") — the precision the
/// design shows.
String _trim(double v) => v < 10 ? v.toStringAsFixed(1) : v.round().toString();

/// 14M · 3.2K · 950 — view counts (Latin digits, like sizes).
String formatCompactCount(int count) {
  String trim(double v) => v >= 10 || v == v.roundToDouble()
      ? v.round().toString()
      : v.toStringAsFixed(1);
  if (count >= 1000000000) return _isolate('${trim(count / 1000000000)}B');
  if (count >= 1000000) return _isolate('${trim(count / 1000000)}M');
  if (count >= 1000) return _isolate('${trim(count / 1000)}K');
  return _isolate('$count');
}

/// 192 kbps
String formatBitrate(int kbps) => _isolate('$kbps kbps');

/// #01 · #12 · #128 — a playlist position.
String formatPlaylistIndex(int index) =>
    _isolate('#${index.toString().padLeft(2, '0')}');
