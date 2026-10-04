import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// A tinted status pill: "Ready", "Resolving…", "Invalid link", "Paused".
/// [color] is a status colour from `ColorsManager`; [busy] swaps the icon for
/// a small spinner.
class StatusChip extends StatelessWidget {
  const StatusChip({
    required this.label,
    required this.color,
    this.icon,
    this.busy = false,
    super.key,
  });

  final String label;
  final Color color;
  final IconData? icon;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final icon = this.icon;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Dimens.radiusPill),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Dimens.space8,
          vertical: Dimens.space4,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (busy)
              SizedBox.square(
                dimension: Dimens.iconSmall,
                child: CircularProgressIndicator(strokeWidth: 2, color: color),
              )
            else if (icon != null)
              Icon(icon, size: Dimens.iconSmall, color: color),
            if (busy || icon != null) horizontalSpace(Dimens.space4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Styles.font12Bold.copyWith(color: color),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
