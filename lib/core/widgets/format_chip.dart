import 'package:flutter/material.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// A small label badge: "60fps", "MP4 · 1080p", "AV1". [highlighted] uses the
/// accent (active / recommended), otherwise a passive surface tag.
class FormatChip extends StatelessWidget {
  const FormatChip(this.label, {this.highlighted = false, super.key});

  final String label;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: highlighted ? colors.primaryContainer : colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Dimens.radiusChip),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.space8,
          vertical: 2,
        ),
        child: Text(
          label,
          style: Styles.font12Bold.copyWith(
            color: highlighted ? ColorsManager.accent : colors.textSecondary,
          ),
        ),
      ),
    );
  }
}
