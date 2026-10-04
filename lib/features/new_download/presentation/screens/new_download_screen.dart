import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/batch_view.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/clipboard_banner.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/link_drop_zone.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/mode_tabs.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/playlist_view.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/single_video_view.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/url_input_bar.dart';

/// New Download tab: mode tabs, the shared URL bar, the clipboard banner, and
/// the three mode views (kept alive in an IndexedStack, so switching tabs
/// doesn't drop a fetched result).
class NewDownloadScreen extends StatelessWidget {
  const NewDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<LinkInputCubit>(
      create: (_) => getIt<LinkInputCubit>()..checkClipboard(),
      child: const _NewDownloadBody(),
    );
  }
}

class _NewDownloadBody extends StatefulWidget {
  const _NewDownloadBody();

  @override
  State<_NewDownloadBody> createState() => _NewDownloadBodyState();
}

class _NewDownloadBodyState extends State<_NewDownloadBody> {
  // Copying a link in the browser, then switching back, should offer it.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onResume: () => context.read<LinkInputCubit>().checkClipboard(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // create it now
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final margin = pageMarginOf(context);
    return BlocBuilder<LinkInputCubit, LinkInputState>(
      buildWhen: (a, b) =>
          a.mode != b.mode || a.clipboardSuggestion != b.clipboardSuggestion,
      builder: (context, state) {
        final suggestion = state.clipboardSuggestion;
        return LinkDropZone(
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: Dimens.maxContentWidth,
              ),
              child: Padding(
                padding: EdgeInsetsDirectional.fromSTEB(
                  margin,
                  Dimens.space16,
                  margin,
                  0,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: ModeTabs(),
                    ),
                    verticalSpace(Dimens.space16),
                    if (state.mode != NewDownloadMode.multiple)
                      const UrlInputBar(),
                    if (suggestion != null) ...[
                      verticalSpace(Dimens.space12),
                      ClipboardBanner(link: suggestion),
                    ],
                    verticalSpace(Dimens.space16),
                    Expanded(
                      child: IndexedStack(
                        index: state.mode.index,
                        children: const [
                          SingleVideoView(),
                          PlaylistView(),
                          BatchView(),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
