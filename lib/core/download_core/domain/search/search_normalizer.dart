/// Folds text for search so what the user types matches what was stored:
/// lower-case, Arabic diacritics and tatweel removed, letter variants unified
/// (أ إ آ ٱ → ا, ى → ي, ة → ه). Applied to stored titles and to queries alike.
abstract final class SearchNormalizer {
  static String normalize(String text) {
    final out = StringBuffer();
    for (final rune in text.toLowerCase().runes) {
      if (_isDiacritic(rune) || rune == 0x0640) continue; // tashkeel, tatweel
      out.writeCharCode(_unify(rune));
    }
    return out.toString().replaceAll(RegExp(r'\s+'), ' ').trim();
  }

  /// Harakat, tanween, shadda, sukun and the superscript alef.
  static bool _isDiacritic(int r) =>
      (r >= 0x064B && r <= 0x065F) || r == 0x0670;

  static int _unify(int r) => switch (r) {
    0x0622 || 0x0623 || 0x0625 || 0x0671 => 0x0627, // alef variants → ا
    0x0649 => 0x064A, // ى → ي
    0x0629 => 0x0647, // ة → ه
    _ => r,
  };
}
