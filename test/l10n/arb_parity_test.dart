import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/error/failure_type.dart';

/// Every key ships in both languages (codebase-conventions skill), and every
/// FailureType has its message (download-errors skill).
void main() {
  Set<String> keysOf(String path) {
    final map =
        jsonDecode(File(path).readAsStringSync()) as Map<String, Object?>;
    return map.keys.where((k) => !k.startsWith('@')).toSet();
  }

  final en = keysOf('lib/l10n/app_en.arb');
  final ar = keysOf('lib/l10n/app_ar.arb');

  test('English and Arabic have the same keys', () {
    expect(en.difference(ar), isEmpty, reason: 'missing in app_ar.arb');
    expect(ar.difference(en), isEmpty, reason: 'missing in app_en.arb');
  });

  test('every FailureType has a failure<Type> message', () {
    for (final type in FailureType.values) {
      final key =
          'failure${type.name[0].toUpperCase()}${type.name.substring(1)}';
      expect(en, contains(key), reason: '$key missing');
    }
  });
}
