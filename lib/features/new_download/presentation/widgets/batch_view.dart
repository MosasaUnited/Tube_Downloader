import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_state.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_footer.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_item_tile.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_links_editor.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_toolbar.dart';

/// The Multiple-links tab. Owns its cubit; takes links dropped on the window
/// or accepted from the clipboard banner through the shared [LinkInputCubit].
class BatchView extends StatelessWidget {
  const BatchView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<BatchLinksCubit>(
      create: (_) => getIt<BatchLinksCubit>(),
      child: const _BatchBody(),
    );
  }
}

class _BatchBody extends StatelessWidget {
  const _BatchBody();

  @override
  Widget build(BuildContext context) {
    return BlocListener<LinkInputCubit, LinkInputState>(
      listenWhen: (a, b) => a.inboxToken != b.inboxToken,
      listener: (context, state) =>
          context.read<BatchLinksCubit>().append(state.inbox),
      child: BlocBuilder<BatchLinksCubit, BatchLinksState>(
        builder: (context, state) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: CustomScrollView(
                slivers: [
                  const SliverToBoxAdapter(child: BatchLinksEditor()),
                  if (state.items.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: EmptyState(
                        icon: Icons.format_list_bulleted,
                        title: context.l10n.batchIdleTitle,
                        body: context.l10n.batchIdleBody,
                      ),
                    )
                  else
                    _ItemSlivers(state: state),
                ],
              ),
            ),
            if (state.items.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: Dimens.space8),
                child: BatchFooter(state: state),
              ),
          ],
        ),
      ),
    );
  }
}

/// Toolbar, swipe hint and the rows, as one sliver of the scroll view.
class _ItemSlivers extends StatelessWidget {
  const _ItemSlivers({required this.state});

  final BatchLinksState state;

  @override
  Widget build(BuildContext context) {
    final items = state.items;
    final compact = windowClassOf(context) == WindowClass.compact;
    return SliverMainAxisGroup(
      slivers: [
        SliverToBoxAdapter(child: verticalSpace(Dimens.space24)),
        SliverToBoxAdapter(child: BatchToolbar(state: state)),
        if (compact)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.only(top: Dimens.space8),
              child: Text(
                context.l10n.batchSwipeHint,
                textAlign: TextAlign.center,
                style: Styles.font12Regular.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ),
          ),
        SliverToBoxAdapter(child: verticalSpace(Dimens.space12)),
        SliverList.builder(
          itemCount: items.length,
          itemBuilder: (context, i) => Padding(
            padding: const EdgeInsets.only(bottom: Dimens.space8),
            child: BatchItemTile(
              key: ValueKey('${items[i].position}-${items[i].input}'),
              item: items[i],
              kind: state.kind,
              estimate: state.estimateOf(items[i]),
            ),
          ),
        ),
      ],
    );
  }
}
