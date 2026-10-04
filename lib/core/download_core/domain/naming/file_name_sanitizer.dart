import 'dart:convert';

import 'package:characters/characters.dart';

/// Makes any title a safe file name on Windows, macOS, Linux, Android and iOS.
abstract final class FileNameSanitizer {
  /// UTF-8 bytes for the base name (extensions are added after); keeps full
  /// paths well under Windows' 260-character limit.
  static const maxBytes = 200;

  static const _windowsReserved = {
    'CON', 'PRN', 'AUX', 'NUL', //
    'COM1', 'COM2', 'COM3', 'COM4', 'COM5', 'COM6', 'COM7', 'COM8', 'COM9',
    'LPT1', 'LPT2', 'LPT3', 'LPT4', 'LPT5', 'LPT6', 'LPT7', 'LPT8', 'LPT9',
  };

  /// Characters no file system accepts, mapped to a readable stand-in.
  static const _replacements = {
    '/': '-', r'\': '-', '|': '-', ':': ' -', '"': "'", //
    '<': '', '>': '', '?': '', '*': '',
  };

  /// Sanitized [name], or [fallback] (e.g. the video id) when nothing usable
  /// is left.
  static String sanitize(String name, {required String fallback}) {
    var s = String.fromCharCodes(name.runes.where((r) => !_isControl(r)));
    for (final entry in _replacements.entries) {
      s = s.replaceAll(entry.key, entry.value);
    }
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    // Windows drops trailing dots/spaces; a leading dot hides the file.
    s = s.replaceAll(RegExp(r'[. ]+$'), '').replaceAll(RegExp(r'^[. ]+'), '');
    s = _truncate(s);
    s = s.replaceAll(RegExp(r'[. ]+$'), '');
    if (s.isEmpty) return fallback;
    final stem = s.split('.').first.toUpperCase();
    return _windowsReserved.contains(stem) ? '_$s' : s;
  }

  /// C0/C1 controls, and bidi controls (U+200E/F, U+202A–202E, U+2066–2069):
  /// a right-to-left override can make "clip[RLO]4pm.exe" display as "clipexe.mp4".
  /// Arabic and other right-to-left letters are kept.
  static bool _isControl(int rune) =>
      rune < 0x20 ||
      (rune >= 0x7F && rune <= 0x9F) ||
      rune == 0x200E ||
      rune == 0x200F ||
      (rune >= 0x202A && rune <= 0x202E) ||
      (rune >= 0x2066 && rune <= 0x2069);

  /// Cuts to [maxBytes] of UTF-8 without splitting a grapheme (an Arabic
  /// letter with its diacritics, an emoji sequence).
  static String _truncate(String s) {
    if (utf8.encode(s).length <= maxBytes) return s;
    final out = StringBuffer();
    var bytes = 0;
    for (final grapheme in s.characters) {
      final size = utf8.encode(grapheme).length;
      if (bytes + size > maxBytes) break;
      out.write(grapheme);
      bytes += size;
    }
    return out.toString();
  }
}
