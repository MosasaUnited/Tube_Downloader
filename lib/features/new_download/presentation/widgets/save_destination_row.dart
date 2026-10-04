import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';

/// Where the file will be saved: [folder], or the platform default when null
/// (changed in Settings — Phase 6 adds the folder picker here too).
class SaveDestinationRow extends StatelessWidget {
  const SaveDestinationRow({required this.folder, super.key});

  final String? folder;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final folder = this.folder;
    return Row(
      children: [
        const Icon(Icons.folder_open_outlined, color: ColorsManager.accent),
        horizontalSpace(Dimens.space12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.saveDestination,
                style: Styles.font12Regular.copyWith(color: colors.textMuted),
              ),
              if (folder == null)
                Text(
                  context.l10n.saveDestinationDefault,
                  style: Styles.font14Regular.copyWith(
                    color: colors.textPrimary,
                  ),
                )
              else
                LtrText(
                  folder,
                  style: Styles.font14Regular.copyWith(
                    color: colors.textPrimary,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
