import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/playlist_footer.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/playlist_header.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/playlist_row_tile.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/playlist_toolbar.dart';

/// The Playlist tab. Owns its cubit; fetches on the shared URL bar's token.
class PlaylistView extends StatelessWidget {
  const PlaylistView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<PlaylistCubit>(
      create: (_) => getIt<PlaylistCubit>(),
      child: const _PlaylistBody(),
    );
  }
}

class _PlaylistBody extends StatelessWidget {
  const _PlaylistBody();

  void _refetch(BuildContext context) {
    final parsed = context.read<LinkInputCubit>().state.parsed;
    if (parsed != null) context.read<PlaylistCubit>().fetch(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<LinkInputCubit, LinkInputState>(
      listenWhen: (a, b) =>
          a.fetchToken != b.fetchToken && b.mode == NewDownloadMode.playlist,
      listener: (context, _) => _refetch(context),
      child: BlocBuilder<PlaylistCubit, PlaylistState>(
        builder: (context, state) => switch (state) {
          PlaylistIdle() => EmptyState(
            icon: Icons.playlist_play,
            title: l10n.playlistIdleTitle,
            body: l10n.playlistIdleBody,
          ),
          PlaylistLoading() => const Center(child: CircularProgressIndicator()),
          PlaylistFailure(:final failure) => EmptyState(
            icon: Icons.error_outline,
            title: failureMessage(context, failure),
            actionLabel: l10n.actionRetry,
            onAction: () => _refetch(context),
          ),
          PlaylistReady() => _ReadyView(state: state),
        },
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.state});

  final PlaylistReady state;

  @override
  Widget build(BuildContext context) {
    final rows = state.visibleRows;
    final stopped = state.itemsFailure;
    return Column(
      children: [
        Expanded(
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: PlaylistHeader(state: state)),
              SliverToBoxAdapter(child: verticalSpace(Dimens.space8)),
              SliverToBoxAdapter(child: PlaylistToolbar(state: state)),
              if (stopped != null)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: Dimens.space8,
                    ),
                    child: Text(
                      '${context.l10n.playlistItemsStopped} ${failureMessage(context, stopped)}',
                      style: Styles.font12Regular.copyWith(
                        color: ColorsManager.warning,
                      ),
                    ),
                  ),
                ),
              SliverToBoxAdapter(child: verticalSpace(Dimens.space8)),
              SliverList.builder(
                itemCount: rows.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: Dimens.space8),
                  child: PlaylistRowTile(
                    key: ValueKey(rows[i].index),
                    row: rows[i],
                    kind: state.kind,
                    estimate: state.estimateOf(rows[i]),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: Dimens.space8),
          child: PlaylistFooter(state: state),
        ),
      ],
    );
  }
}
