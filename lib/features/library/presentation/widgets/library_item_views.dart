import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/format_chip.dart';
import 'package:tube_downloader/core/widgets/media_thumbnail.dart';
import 'package:tube_downloader/core/widgets/status_chip.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_cubit.dart';
import 'package:tube_downloader/features/library/presentation/library_actions.dart';
import 'package:tube_downloader/features/library/presentation/library_labels.dart';

/// A grid card: thumbnail (the saved copy — the library works offline),
/// title, format, size, when. Tap opens (or selects, while selecting); a long
/// press starts selecting.
class LibraryCard extends StatelessWidget {
  const LibraryCard({
    required this.item,
    required this.selecting,
    required this.selected,
    super.key,
  });

  final LibraryItem item;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return _Selectable(
      item: item,
      selecting: selecting,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Fills the card's width: no LayoutBuilder, which can't answer
            // the IntrinsicHeight row of the grid.
            Stack(
              children: [
                _Thumb(item: item),
                if (selecting)
                  PositionedDirectional(
                    top: Dimens.space4,
                    start: Dimens.space4,
                    child: _Check(selected: selected),
                  ),
              ],
            ),
            verticalSpace(Dimens.space8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Styles.font14Bold.copyWith(
                      color: colors.textPrimary,
                    ),
                  ),
                ),
                if (!selecting) LibraryItemMenu(item: item),
              ],
            ),
            verticalSpace(Dimens.space4),
            _Meta(item: item),
          ],
        ),
      ),
    );
  }
}

/// The list-view row of the same item.
class LibraryListTile extends StatelessWidget {
  const LibraryListTile({
    required this.item,
    required this.selecting,
    required this.selected,
    super.key,
  });

  final LibraryItem item;
  final bool selecting;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return _Selectable(
      item: item,
      selecting: selecting,
      selected: selected,
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space8),
        child: Row(
          children: [
            if (selecting) ...[
              _Check(selected: selected),
              horizontalSpace(Dimens.space8),
            ],
            _Thumb(item: item, width: 112),
            horizontalSpace(Dimens.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Styles.font14Bold.copyWith(
                      color: context.colors.textPrimary,
                    ),
                  ),
                  verticalSpace(Dimens.space4),
                  _Meta(item: item),
                ],
              ),
            ),
            if (!selecting) LibraryItemMenu(item: item),
          ],
        ),
      ),
    );
  }
}

/// Open · Show in folder · Share · Copy link · Delete.
class LibraryItemMenu extends StatelessWidget {
  const LibraryItemMenu({required this.item, super.key});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<LibraryCubit>();
    PopupMenuItem<VoidCallback> entry(
      IconData icon,
      String label,
      VoidCallback action, {
      Color? color,
    }) => PopupMenuItem<VoidCallback>(
      value: action,
      child: Row(
        children: [
          Icon(icon, size: Dimens.iconSize, color: color),
          horizontalSpace(Dimens.space12),
          Text(label, style: Styles.font14Regular.copyWith(color: color)),
        ],
      ),
    );
    return PopupMenuButton<VoidCallback>(
      tooltip: l10n.actionMore,
      icon: const Icon(Icons.more_vert),
      onSelected: (action) => action(),
      itemBuilder: (menuContext) => [
        if (!item.missing)
          entry(
            Icons.play_circle_outline,
            l10n.actionOpen,
            () => LibraryActions.open(context, item),
          ),
        if (cubit.canReveal && !item.missing)
          entry(
            Icons.folder_open_outlined,
            l10n.actionShowInFolder,
            () => LibraryActions.reveal(context, item),
          ),
        if (!item.missing)
          entry(
            Icons.share_outlined,
            l10n.actionShare,
            () => LibraryActions.share(context, [item]),
          ),
        entry(
          Icons.link,
          l10n.actionCopyLink,
          () => LibraryActions.copyLink(context, item),
        ),
        entry(
          Icons.delete_outline,
          l10n.actionDelete,
          () => LibraryActions.delete(context, [item]),
          color: ColorsManager.error,
        ),
      ],
    );
  }
}

/// The card frame: selected border, tap / long-press behaviour, dimmed when
/// the file is missing.
class _Selectable extends StatelessWidget {
  const _Selectable({
    required this.item,
    required this.selecting,
    required this.selected,
    required this.child,
  });

  final LibraryItem item;
  final bool selecting;
  final bool selected;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryCubit>();
    return Opacity(
      opacity: item.missing ? 0.55 : 1,
      child: Card(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
          side: BorderSide(
            color: selected ? ColorsManager.primary : context.colors.border,
            width: selected ? 2 : Dimens.borderWidth,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(Dimens.radiusCard),
          onTap: selecting
              ? () => cubit.toggle(item.id)
              : item.missing
              ? null
              : () => LibraryActions.open(context, item),
          onLongPress: () => cubit.toggle(item.id),
          child: child,
        ),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.item, this.width});

  final LibraryItem item;

  /// null = the card's full width.
  final double? width;

  @override
  Widget build(BuildContext context) {
    return MediaThumbnail(
      url: null,
      filePath: item.thumbPath,
      width: width,
      duration: item.duration,
      placeholderIcon: item.kind == MediaKind.audio
          ? Icons.graphic_eq
          : Icons.movie_outlined,
    );
  }
}

/// "MP4 · 1080p  245 MB" and "3 days ago" — or the missing-file flag.
class _Meta extends StatelessWidget {
  const _Meta({required this.item});

  final LibraryItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final muted = Styles.font12Regular.copyWith(color: colors.textSecondary);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: Dimens.space8,
          runSpacing: Dimens.space4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FormatChip(
              formatFileLabel(item.container, item.height),
              highlighted: true,
            ),
            Text(formatBytes(item.bytes), style: muted),
          ],
        ),
        verticalSpace(Dimens.space4),
        if (item.missing)
          StatusChip(
            label: context.l10n.fileMissingBadge,
            color: ColorsManager.warning,
            icon: Icons.warning_amber_rounded,
          )
        else
          Text(relativeDay(context, item.completedAt), style: muted),
      ],
    );
  }
}

class _Check extends StatelessWidget {
  const _Check({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? ColorsManager.primary : ColorsManager.scrim,
        borderRadius: BorderRadius.circular(Dimens.radiusChip),
        border: Border.all(color: ColorsManager.white, width: 1.5),
      ),
      child: SizedBox.square(
        dimension: Dimens.iconSize + Dimens.space4,
        child: selected
            ? const Icon(
                Icons.check,
                size: Dimens.iconSize,
                color: ColorsManager.onPrimary,
              )
            : null,
      ),
    );
  }
}
