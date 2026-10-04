import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/single_link_cubit/single_link_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/format_options_panel.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/media_preview_card.dart';

/// The Single video tab. Owns its cubit; fetches when the shared URL bar
/// asks (LinkInputState.fetchToken).
class SingleVideoView extends StatelessWidget {
  const SingleVideoView({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SingleLinkCubit>(
      create: (_) => getIt<SingleLinkCubit>(),
      child: const _SingleVideoBody(),
    );
  }
}

class _SingleVideoBody extends StatelessWidget {
  const _SingleVideoBody();

  void _refetch(BuildContext context) {
    final parsed = context.read<LinkInputCubit>().state.parsed;
    if (parsed != null) context.read<SingleLinkCubit>().fetch(parsed);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return BlocListener<LinkInputCubit, LinkInputState>(
      listenWhen: (a, b) =>
          a.fetchToken != b.fetchToken && b.mode == NewDownloadMode.single,
      listener: (context, _) => _refetch(context),
      child: BlocBuilder<SingleLinkCubit, SingleLinkState>(
        builder: (context, state) => switch (state) {
          SingleIdle() => EmptyState(
            icon: Icons.link,
            title: l10n.singleIdleTitle,
            body: l10n.singleIdleBody,
          ),
          SingleLoading() => const _LoadingView(),
          SingleFailure(:final failure) => EmptyState(
            icon: Icons.error_outline,
            title: failureMessage(context, failure),
            actionLabel: l10n.actionRetry,
            onAction: () => _refetch(context),
          ),
          SingleReady() => _ReadyView(state: state),
        },
      ),
    );
  }
}

class _ReadyView extends StatelessWidget {
  const _ReadyView({required this.state});

  final SingleReady state;

  @override
  Widget build(BuildContext context) {
    if (windowClassOf(context) == WindowClass.compact) {
      // Phone: options scroll under the preview; Download stays in reach.
      return Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: Dimens.space16),
              children: [
                MediaPreviewCard(media: state.media),
                verticalSpace(Dimens.space12),
                FormatOptionsPanel(state: state, includeButton: false),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: Dimens.space8),
            child: SizedBox(
              width: double.infinity,
              child: DownloadButton(state: state),
            ),
          ),
        ],
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: Dimens.space24),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: MediaPreviewCard(media: state.media)),
          horizontalSpace(Dimens.space16),
          Expanded(flex: 3, child: FormatOptionsPanel(state: state)),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms);
  }
}

/// Placeholder shapes while the video's details load.
class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    Widget block(double height) => Container(
      height: height,
      margin: const EdgeInsets.only(bottom: Dimens.space8),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(Dimens.radiusButton),
      ),
    );
    return SingleChildScrollView(
      child:
          Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.fetchingDetails,
                    style: Styles.font14Regular.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  verticalSpace(Dimens.space16),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 520),
                    child: Column(
                      children: [
                        AspectRatio(aspectRatio: 16 / 9, child: block(0)),
                        for (var i = 0; i < 4; i++)
                          block(Dimens.touchTarget + Dimens.space8),
                      ],
                    ),
                  ),
                ],
              )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1200.ms, color: colors.surface),
    );
  }
}
