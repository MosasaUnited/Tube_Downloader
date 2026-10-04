import 'package:flutter/widgets.dart';
import 'package:tube_downloader/core/theme/font_weight_helper.dart';

/// The type ladder: `font<size><Weight>`, no colour baked in — add it per call
/// site with `.copyWith(color: context.colors.textSecondary)`. Line heights
/// follow the Stitch design system. A size/weight pair that is missing is added
/// here, never built inline (review-gate blocks a bare `TextStyle(`).
///
/// Desktop headings use 20/24/32, mobile headings 18/22/28 (the two Stitch
/// design systems differ); body and labels are shared.
abstract final class Styles {
  static const font12Regular = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeightHelper.regular,
  );
  static const font12Bold = TextStyle(
    fontSize: 12,
    height: 16 / 12,
    fontWeight: FontWeightHelper.bold,
  );
  static const font14Regular = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeightHelper.regular,
  );
  static const font14Bold = TextStyle(
    fontSize: 14,
    height: 20 / 14,
    fontWeight: FontWeightHelper.bold,
  );
  static const font16Regular = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeightHelper.regular,
  );
  static const font16Bold = TextStyle(
    fontSize: 16,
    height: 24 / 16,
    fontWeight: FontWeightHelper.bold,
  );
  static const font18Bold = TextStyle(
    fontSize: 18,
    height: 24 / 18,
    fontWeight: FontWeightHelper.bold,
  );
  static const font20Bold = TextStyle(
    fontSize: 20,
    height: 28 / 20,
    fontWeight: FontWeightHelper.bold,
  );
  static const font22Bold = TextStyle(
    fontSize: 22,
    height: 28 / 22,
    fontWeight: FontWeightHelper.bold,
  );
  static const font24Bold = TextStyle(
    fontSize: 24,
    height: 32 / 24,
    fontWeight: FontWeightHelper.bold,
  );
  static const font28Bold = TextStyle(
    fontSize: 28,
    height: 36 / 28,
    fontWeight: FontWeightHelper.bold,
  );
  static const font32Bold = TextStyle(
    fontSize: 32,
    height: 40 / 32,
    fontWeight: FontWeightHelper.bold,
  );
}
