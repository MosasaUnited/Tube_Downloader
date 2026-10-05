import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';
import 'package:tube_downloader/core/widgets/progress_track.dart';
import 'package:tube_downloader/features/shell/logic/storage_meter_cubit/storage_meter_cubit.dart';
import 'package:tube_downloader/features/shell/logic/storage_meter_cubit/storage_meter_state.dart';

/// The bottom of the desktop sidebar: free space of the save drive and the
/// save folder. Opens Settings. Hidden while nothing is known.
class StorageMeter extends StatelessWidget {
  const StorageMeter({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<StorageMeterCubit>(
      create: (_) => getIt<StorageMeterCubit>()..start(),
      child: BlocBuilder<StorageMeterCubit, StorageMeterState>(
        builder: (context, state) {
          final space = state.space;
          final folder = state.folder;
          if (space == null && folder == null) return const SizedBox.shrink();
          final colors = context.colors;
          final l10n = context.l10n;
          final low = space != null && space.freeBytes < space.totalBytes / 10;
          return Material(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(Dimens.radiusButton),
            child: InkWell(
              borderRadius: BorderRadius.circular(Dimens.radiusButton),
              onTap: () => context.go(AppRoutes.settings),
              child: Padding(
                padding: const EdgeInsets.all(Dimens.space12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      l10n.settingsStorage,
                      style: Styles.font12Bold.copyWith(
                        color: colors.textMuted,
                      ),
                    ),
                    if (space != null) ...[
                      verticalSpace(Dimens.space4),
                      Text(
                        l10n.storageFreeOfTotal(
                          formatBytes(space.freeBytes),
                          formatBytes(space.totalBytes),
                        ),
                        style: Styles.font12Bold.copyWith(
                          color: colors.textPrimary,
                        ),
                      ),
                      verticalSpace(Dimens.space8),
                      ProgressTrack(
                        value: space.usedFraction,
                        color: low
                            ? ColorsManager.warning
                            : ColorsManager.accent,
                      ),
                    ],
                    if (folder != null) ...[
                      verticalSpace(Dimens.space8),
                      Row(
                        children: [
                          Icon(
                            Icons.folder_outlined,
                            size: Dimens.iconSmall,
                            color: colors.textSecondary,
                          ),
                          horizontalSpace(Dimens.space8),
                          Expanded(
                            child: LtrText(
                              folder,
                              style: Styles.font12Regular.copyWith(
                                color: colors.textSecondary,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
