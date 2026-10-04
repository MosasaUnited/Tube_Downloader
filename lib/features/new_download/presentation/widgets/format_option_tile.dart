import 'package:flutter/material.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/format_chip.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/format_labels.dart';

/// One quality row: radio, "1080p Full HD", 60fps chip, "MP4 · H.264", ~size.
class FormatOptionTile extends StatelessWidget {
  const FormatOptionTile({
    required this.option,
    required this.selected,
    required this.recommended,
    required this.onTap,
    super.key,
  });

  final FormatOption option;
  final bool selected;
  final bool recommended;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final l10n = context.l10n;
    final bytes = option.estimatedBytes;
    final fps = option.fps;
    return Semantics(
      selected: selected,
      inMutuallyExclusiveGroup: true,
      button: true,
      child: Material(
        color: selected ? colors.surfaceRaised : ColorsManager.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusButton),
          side: BorderSide(
            color: selected ? ColorsManager.primary : colors.border,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.radiusButton),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              minHeight: Dimens.touchTarget + Dimens.space8,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Dimens.space12,
                vertical: Dimens.space8,
              ),
              child: Row(
                children: [
                  Icon(
                    selected
                        ? Icons.radio_button_checked
                        : Icons.radio_button_unchecked,
                    color: selected ? ColorsManager.accent : colors.textMuted,
                  ),
                  horizontalSpace(Dimens.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: Dimens.space8,
                          runSpacing: Dimens.space4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              FormatLabels.title(option),
                              style: Styles.font16Bold.copyWith(
                                color: colors.textPrimary,
                              ),
                            ),
                            if (fps != null && fps > 30)
                              FormatChip('${fps}fps', highlighted: true),
                            if (recommended) FormatChip(l10n.formatRecommended),
                          ],
                        ),
                        Text(
                          FormatLabels.detail(option),
                          style: Styles.font12Regular.copyWith(
                            color: colors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (bytes != null)
                    Text(
                      l10n.approximately(formatBytes(bytes)),
                      style: Styles.font14Bold.copyWith(
                        color: selected
                            ? ColorsManager.accent
                            : colors.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
