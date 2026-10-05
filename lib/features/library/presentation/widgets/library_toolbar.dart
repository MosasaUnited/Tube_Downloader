import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_cubit.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_state.dart';

/// "24 files" · Select · Sort · Grid/List, the search field, and the
/// All / Video / Audio chips with their counts.
class LibraryToolbar extends StatelessWidget {
  const LibraryToolbar({
    required this.state,
    required this.searchController,
    required this.searchFocus,
    super.key,
  });

  final LibraryState state;
  final TextEditingController searchController;
  final FocusNode searchFocus;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final cubit = context.read<LibraryCubit>();
    final compact = windowClassOf(context) == WindowClass.compact;
    final search = _SearchField(
      controller: searchController,
      focus: searchFocus,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Phones: icons with tooltips — labels don't fit at large text.
        if (compact)
          IconButton(
            tooltip: state.selecting ? l10n.actionDone : l10n.actionSelect,
            onPressed: () => cubit.setSelecting(!state.selecting),
            icon: Icon(state.selecting ? Icons.close : Icons.checklist),
          )
        else if (state.selecting)
          TextButton(
            onPressed: () => cubit.setSelecting(false),
            child: Text(l10n.actionDone),
          )
        else
          TextButton.icon(
            onPressed: () => cubit.setSelecting(true),
            icon: const Icon(Icons.checklist),
            label: Text(l10n.actionSelect),
          ),
        _SortMenu(sort: state.sort, iconOnly: compact),
        IconButton(
          tooltip: state.view == LibraryView.grid
              ? l10n.viewList
              : l10n.viewGrid,
          onPressed: () => cubit.setView(
            state.view == LibraryView.grid
                ? LibraryView.list
                : LibraryView.grid,
          ),
          icon: Icon(
            state.view == LibraryView.grid
                ? Icons.view_list_outlined
                : Icons.grid_view_outlined,
          ),
        ),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                l10n.libraryFilesCount(state.countOf(null)),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Styles.font16Bold.copyWith(color: colors.textSecondary),
              ),
            ),
            if (!compact) ...[
              horizontalSpace(Dimens.space16),
              Expanded(flex: 2, child: search),
            ] else
              const Spacer(),
            horizontalSpace(Dimens.space8),
            actions,
          ],
        ),
        if (compact) ...[verticalSpace(Dimens.space12), search],
        verticalSpace(Dimens.space12),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final (kind, label) in [
                (null, l10n.filterAll),
                (MediaKind.video, l10n.libraryVideo),
                (MediaKind.audio, l10n.libraryAudio),
              ]) ...[
                ChoiceChip(
                  selected: state.kind == kind,
                  onSelected: (_) => cubit.setKind(kind),
                  showCheckmark: false,
                  selectedColor: ColorsManager.primary,
                  label: Text(
                    '$label  ${state.countOf(kind)}',
                    style: Styles.font14Bold.copyWith(
                      color: state.kind == kind
                          ? ColorsManager.onPrimary
                          : colors.textSecondary,
                    ),
                  ),
                ),
                horizontalSpace(Dimens.space8),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.focus});

  final TextEditingController controller;
  final FocusNode focus;

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<LibraryCubit>();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, _) => TextField(
        controller: controller,
        focusNode: focus,
        onChanged: cubit.setQuery,
        textInputAction: TextInputAction.search,
        decoration: InputDecoration(
          isDense: true,
          hintText: context.l10n.librarySearchHint,
          prefixIcon: const Icon(Icons.search),
          suffixIcon: value.text.isEmpty
              ? null
              : IconButton(
                  tooltip: context.l10n.actionClearAll,
                  onPressed: () {
                    controller.clear();
                    cubit.setQuery('');
                  },
                  icon: const Icon(Icons.cancel_outlined),
                ),
        ),
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sort, required this.iconOnly});

  final LibrarySort sort;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final labels = {
      LibrarySort.newest: l10n.sortNewest,
      LibrarySort.oldest: l10n.sortOldest,
      LibrarySort.name: l10n.sortName,
      LibrarySort.size: l10n.sortSize,
    };
    return PopupMenuButton<LibrarySort>(
      tooltip: l10n.sortLabel,
      initialValue: sort,
      onSelected: context.read<LibraryCubit>().setSort,
      itemBuilder: (_) => [
        for (final entry in labels.entries)
          PopupMenuItem(value: entry.key, child: Text(entry.value)),
      ],
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space12),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sort),
            if (!iconOnly) ...[
              horizontalSpace(Dimens.space4),
              Text(
                labels[sort]!,
                style: Styles.font14Bold.copyWith(
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
