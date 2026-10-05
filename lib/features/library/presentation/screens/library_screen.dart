import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_cubit.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_state.dart';
import 'package:tube_downloader/features/library/presentation/widgets/library_item_views.dart';
import 'package:tube_downloader/features/library/presentation/widgets/library_toolbar.dart';
import 'package:tube_downloader/features/library/presentation/widgets/selection_bar.dart';

/// The Library tab: finished files as a grid or a list, searchable (⌘F /
/// Ctrl+F on desktop), with multi-select actions.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LibraryCubit>(
      create: (_) => getIt<LibraryCubit>()..start(),
      child: const _LibraryBody(),
    );
  }
}

class _LibraryBody extends StatefulWidget {
  const _LibraryBody();

  @override
  State<_LibraryBody> createState() => _LibraryBodyState();
}

class _LibraryBodyState extends State<_LibraryBody> {
  // The search field's text and focus: UI state, owned here so the ⌘F
  // shortcut can reach the field.
  final _search = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _search.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final margin = pageMarginOf(context);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, meta: true):
            _searchFocus.requestFocus,
        const SingleActivator(LogicalKeyboardKey.keyF, control: true):
            _searchFocus.requestFocus,
      },
      child: Focus(
        autofocus: true,
        child: BlocBuilder<LibraryCubit, LibraryState>(
          builder: (context, state) {
            if (!state.loaded) {
              return const Center(child: CircularProgressIndicator());
            }
            if (state.matches.isEmpty && state.query.isEmpty) {
              final l10n = context.l10n;
              return EmptyState(
                icon: Icons.video_library_outlined,
                title: l10n.emptyLibraryTitle,
                body: l10n.emptyLibraryBody,
                actionLabel: l10n.emptyDownloadsAction,
                onAction: () => context.go(AppRoutes.newDownload),
              );
            }
            return Padding(
              padding: EdgeInsetsDirectional.fromSTEB(
                margin,
                Dimens.space16,
                margin,
                0,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  LibraryToolbar(
                    state: state,
                    searchController: _search,
                    searchFocus: _searchFocus,
                  ),
                  verticalSpace(Dimens.space12),
                  Expanded(child: _Items(state: state)),
                  if (state.selecting)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        vertical: Dimens.space8,
                      ),
                      child: SelectionBar(state: state),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Items extends StatelessWidget {
  const _Items({required this.state});

  final LibraryState state;

  /// The narrowest a grid card gets before a column is dropped.
  static const _minCardWidth = 240.0;

  @override
  Widget build(BuildContext context) {
    final items = state.visible;
    if (items.isEmpty) {
      return EmptyState(
        icon: Icons.search_off,
        title: context.l10n.librarySearchEmpty,
      );
    }
    if (state.view == LibraryView.list) {
      return ListView.builder(
        padding: const EdgeInsets.only(bottom: Dimens.space24),
        itemCount: items.length,
        itemBuilder: (context, i) => Padding(
          padding: const EdgeInsets.only(bottom: Dimens.space8),
          child: LibraryListTile(
            key: ValueKey(items[i].id),
            item: items[i],
            selecting: state.selecting,
            selected: state.selected.contains(items[i].id),
          ),
        ),
      );
    }
    // Rows of equal-width cards in IntrinsicHeight — never a fixed aspect
    // ratio, which clips text at large sizes (adaptive-layout skill).
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = math.max(
          2,
          (constraints.maxWidth / _minCardWidth).floor(),
        );
        final rows = (items.length / columns).ceil();
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: Dimens.space24),
          itemCount: rows,
          itemBuilder: (context, row) => IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var c = 0; c < columns; c++)
                  Expanded(
                    child: row * columns + c < items.length
                        ? _GridCell(
                            item: items[row * columns + c],
                            state: state,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _GridCell extends StatelessWidget {
  const _GridCell({required this.item, required this.state});

  final LibraryItem item;
  final LibraryState state;

  @override
  Widget build(BuildContext context) => LibraryCard(
    key: ValueKey(item.id),
    item: item,
    selecting: state.selecting,
    selected: state.selected.contains(item.id),
  );
}
