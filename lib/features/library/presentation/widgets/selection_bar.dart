import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_cubit.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_state.dart';
import 'package:tube_downloader/features/library/presentation/library_actions.dart';

/// "3 items selected · 840 MB total" with Select all, Share, Photos (phones,
/// videos only) and Delete.
class SelectionBar extends StatelessWidget {
  const SelectionBar({required this.state, super.key});

  final LibraryState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<LibraryCubit>();
    final items = state.selectedItems;
    final shareable = items.where((i) => !i.missing).toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: Dimens.space16,
          runSpacing: Dimens.space8,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle_outline,
                  color: ColorsManager.primary,
                ),
                horizontalSpace(Dimens.space8),
                Flexible(
                  child: Text(
                    [
                      l10n.selectedCount(items.length),
                      if (items.isNotEmpty)
                        l10n.sizeTotal(formatBytes(state.selectedBytes)),
                    ].join(' · '),
                    style: Styles.font14Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            Wrap(
              spacing: Dimens.space8,
              runSpacing: Dimens.space8,
              children: [
                TextButton(
                  onPressed: cubit.selectAll,
                  child: Text(l10n.actionSelectAll),
                ),
                Builder(
                  // Its own context: the share sheet points at this button.
                  builder: (anchor) => OutlinedButton.icon(
                    onPressed: shareable.isEmpty
                        ? null
                        : () => LibraryActions.share(
                            context,
                            shareable,
                            anchor: anchor,
                          ),
                    icon: const Icon(Icons.share_outlined),
                    label: Text(l10n.actionShare),
                  ),
                ),
                if (cubit.canSaveToPhotos)
                  OutlinedButton.icon(
                    onPressed: state.selectionHasVideo
                        ? () => LibraryActions.saveToPhotos(context, items)
                        : null,
                    icon: const Icon(Icons.photo_library_outlined),
                    label: Text(l10n.actionSaveToPhotos),
                  ),
                FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: ColorsManager.error,
                  ),
                  onPressed: items.isEmpty
                      ? null
                      : () => LibraryActions.delete(context, items),
                  icon: const Icon(Icons.delete_outline),
                  label: Text(l10n.actionDelete),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
