import 'package:tube_downloader/core/download_core/domain/naming/file_name_sanitizer.dart';

/// The user's file-name pattern, e.g. `{title} - {channel}`.
abstract final class FileNameTemplate {
  static const defaultTemplate = '{title} - {channel}';
  static const placeholders = {
    'title',
    'channel',
    'id',
    'quality',
    'index',
    'date',
  };
  static final _token = RegExp(r'\{([a-z]+)\}');

  /// Placeholders the template uses that this app does not know (Settings
  /// rejects the template while this is non-empty).
  static Set<String> unknownPlaceholders(String template) => _token
      .allMatches(template)
      .map((m) => m.group(1)!)
      .where((p) => !placeholders.contains(p))
      .toSet();

  /// The base file name (no extension), sanitized; falls back to the video id.
  static String render(
    String template, {
    required String title,
    required String channel,
    required String videoId,
    String? quality,
    int? index,
    int indexWidth = 2,
    DateTime? date,
  }) {
    final values = {
      'title': title,
      'channel': channel,
      'id': videoId,
      'quality': quality ?? '',
      'index': index == null ? '' : index.toString().padLeft(indexWidth, '0'),
      'date': date == null ? '' : _date(date),
    };
    final raw = template.replaceAllMapped(
      _token,
      (m) => values[m.group(1)] ?? '',
    );
    // A missing optional value leaves separators behind ("Title -  -"): tidy.
    final tidy = raw
        .replaceAll(RegExp(r'(\s*-\s*){2,}'), ' - ')
        .replaceAll(RegExp(r'^\s*-\s*|\s*-\s*$'), '');
    return FileNameSanitizer.sanitize(tidy, fallback: videoId);
  }

  static String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}
