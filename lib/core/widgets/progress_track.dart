import 'package:flutter/material.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';

/// The thin rounded progress bar of the queue cards. [value] 0–1, or null
/// while the size is unknown (indeterminate).
class ProgressTrack extends StatelessWidget {
  const ProgressTrack({
    required this.value,
    this.color = ColorsManager.accent,
    super.key,
  });

  final double? value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(Dimens.radiusPill),
      child: LinearProgressIndicator(
        value: value?.clamp(0, 1),
        minHeight: Dimens.progressTrackHeight,
        color: color,
        backgroundColor: context.colors.border,
      ),
    );
  }
}

/// The large ring of the details pane, with [child] (percent, speed) inside.
class ProgressRing extends StatelessWidget {
  const ProgressRing({
    required this.value,
    required this.child,
    this.size = 176,
    this.color = ColorsManager.accent,
    super.key,
  });

  final double? value;
  final Widget child;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(
            child: CircularProgressIndicator(
              value: value?.clamp(0, 1),
              strokeWidth: Dimens.space12,
              strokeCap: StrokeCap.round,
              color: color,
              backgroundColor: context.colors.border,
            ),
          ),
          Padding(padding: const EdgeInsets.all(Dimens.space24), child: child),
        ],
      ),
    );
  }
}
