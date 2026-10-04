import 'dart:io';

import 'package:flutter/services.dart';

/// Loads the bundled Almarai family and the Material icon font, so golden
/// images show real text and icons instead of the test font's boxes.
/// Goldens are rasterized by the host and recorded on macOS only
/// (dart_test.yaml, tag `golden`).
Future<void> loadAppFonts() async {
  final almarai = FontLoader('Almarai');
  for (final weight in ['Light', 'Regular', 'Bold', 'ExtraBold']) {
    almarai.addFont(rootBundle.load('assets/fonts/Almarai-$weight.ttf'));
  }
  await almarai.load();

  // FLUTTER_ROOT is set by `flutter test`; the icon font ships with the SDK.
  final root = Platform.environment['FLUTTER_ROOT'];
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (root != null && icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then(ByteData.sublistView));
    await loader.load();
  }
}
