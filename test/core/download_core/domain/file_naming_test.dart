import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/domain/naming/file_name_sanitizer.dart';
import 'package:tube_downloader/core/download_core/domain/naming/file_name_template.dart';

String _clean(String s) =>
    FileNameSanitizer.sanitize(s, fallback: 'R6MlUcmOul8');

void main() {
  group('sanitizer', () {
    test('characters no file system accepts', () {
      expect(_clean('Part 1/2: Intro <draft>?*'), 'Part 1-2 - Intro draft');
      expect(_clean(r'a\b|c"d'), "a-b-c'd");
    });

    test('control and bidi-control characters are removed (spoofing)', () {
      final rlo = String.fromCharCode(0x202E);
      final isolate = String.fromCharCode(0x2068);
      expect(_clean('clip${rlo}4pm.exe'), 'clip4pm.exe');
      expect(_clean('a${isolate}b\tc\nd'), 'abcd');
    });

    test('Arabic titles are kept intact', () {
      expect(
        _clean('تعلم البرمجة - الدرس الأول'),
        'تعلم البرمجة - الدرس الأول',
      );
    });

    test('trailing dots/spaces and leading dots', () {
      expect(_clean('  .hidden title...  '), 'hidden title');
    });

    test('Windows reserved names are prefixed', () {
      expect(_clean('CON'), '_CON');
      expect(_clean('nul.mp4 notes'), '_nul.mp4 notes');
      expect(_clean('Console'), 'Console');
    });

    test(
      'long names are cut to 200 UTF-8 bytes without splitting a character',
      () {
        final arabic = 'م' * 300; // 2 bytes each
        final cut = _clean(arabic);
        expect(
          utf8.encode(cut).length,
          lessThanOrEqualTo(FileNameSanitizer.maxBytes),
        );
        expect(cut, 'م' * 100);
        final emoji = '👍🏽' * 60; // a two-code-point grapheme, 8 bytes
        expect(
          _clean(emoji).runes.length.isEven,
          isTrue,
          reason: 'no half emoji',
        );
      },
    );

    test('nothing usable falls back to the id', () {
      expect(_clean('???'), 'R6MlUcmOul8');
      expect(_clean('   '), 'R6MlUcmOul8');
    });
  });

  group('template', () {
    test('the default template', () {
      expect(
        FileNameTemplate.render(
          FileNameTemplate.defaultTemplate,
          title: 'Tears of Steel',
          channel: 'Blender',
          videoId: 'x',
        ),
        'Tears of Steel - Blender',
      );
    });

    test('index is zero-padded; empty optional values leave no dangling separators', () {
      expect(
        FileNameTemplate.render(
          '{index} - {title} - {quality}',
          title: 'Intro',
          channel: 'c',
          videoId: 'x',
          index: 3,
        ),
        '03 - Intro',
      );
    });

    test('unknown placeholders are reported for Settings validation', () {
      expect(FileNameTemplate.unknownPlaceholders('{title} {author} {id}'), {
        'author',
      });
      expect(
        FileNameTemplate.unknownPlaceholders(FileNameTemplate.defaultTemplate),
        isEmpty,
      );
    });
  });
}
