/// Pulls link text out of a file the user picked or dropped: a `.txt` list
/// (as is), a macOS `.webloc` bookmark, or a Windows `.url` shortcut. Pure —
/// reading the bytes is the platform layer's job.
abstract final class LinkFileExtractor {
  static const extensions = {'txt', 'webloc', 'url'};

  static final _plistString = RegExp(r'<string>([^<]+)</string>');
  static final _urlLine = RegExp(r'^URL=(.+)$', multiLine: true);

  /// Any http(s) URL — the fallback for binary `.webloc` property lists.
  static final _anyUrl = RegExp(r'https?://[^\s<>"\x00-\x1f]+');

  static bool supports(String fileName) =>
      extensions.contains(_extension(fileName));

  /// The links inside [content], or null when the file holds none.
  static String? extract(String fileName, String content) {
    final text = content.replaceAll('\uFEFF', ''); // a UTF-8 BOM
    final links = switch (_extension(fileName)) {
      'txt' => text,
      'webloc' =>
        _plistString.firstMatch(text)?.group(1)?.replaceAll('&amp;', '&') ??
            _anyUrl.firstMatch(text)?.group(0),
      'url' => _urlLine.firstMatch(text)?.group(1),
      _ => null,
    };
    final trimmed = links?.trim();
    return trimmed == null || trimmed.isEmpty ? null : trimmed;
  }

  static String _extension(String fileName) {
    final dot = fileName.lastIndexOf('.');
    return dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
  }
}
