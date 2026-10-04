import 'package:flutter/widgets.dart';

/// The four weights the bundled Almarai files provide (pubspec.yaml). Feature
/// code takes a weight from a `Styles` rung, never a raw `FontWeight`.
abstract final class FontWeightHelper {
  static const light = FontWeight.w300;
  static const regular = FontWeight.w400;
  static const bold = FontWeight.w700;
  static const extraBold = FontWeight.w800;
}
