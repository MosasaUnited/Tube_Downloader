import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';

/// Downloads tab. Phase 1 shows the empty state; Phase 4 adds the queue.
class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return EmptyState(
      icon: Icons.download_outlined,
      title: l10n.emptyDownloadsTitle,
      body: l10n.emptyDownloadsBody,
      actionLabel: l10n.emptyDownloadsAction,
      onAction: () => context.go(AppRoutes.newDownload),
    );
  }
}
