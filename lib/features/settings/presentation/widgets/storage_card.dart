import 'package:flutter/material.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/progress_track.dart';

/// Free and total space of the drive downloads are saved to. (The design's
/// System / Other split is invented telemetry: not shown.)
class StorageCard extends StatelessWidget {
  const StorageCard({required this.space, super.key});

  final StorageSpace? space;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final space = this.space;
    // Under 10 % free the bar turns amber: downloads may soon be refused.
    final low = space != null && space.freeBytes < space.totalBytes / 10;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.storage_outlined, color: ColorsManager.accent),
                horizontalSpace(Dimens.space12),
                Expanded(
                  child: Text(
                    l10n.settingsStorage,
                    style: Styles.font18Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (space != null)
                  Text(
                    l10n.storageUsedPercent(formatPercent(space.usedFraction)),
                    style: Styles.font14Bold.copyWith(
                      color: low ? ColorsManager.warning : ColorsManager.accent,
                    ),
                  ),
              ],
            ),
            verticalSpace(Dimens.space8),
            Text(
              space == null
                  ? l10n.storageUnknown
                  : l10n.storageFreeOfTotal(
                      formatBytes(space.freeBytes),
                      formatBytes(space.totalBytes),
                    ),
              style: Styles.font14Regular.copyWith(color: colors.textSecondary),
            ),
            if (space != null) ...[
              verticalSpace(Dimens.space12),
              ProgressTrack(
                value: space.usedFraction,
                color: low ? ColorsManager.warning : ColorsManager.accent,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
