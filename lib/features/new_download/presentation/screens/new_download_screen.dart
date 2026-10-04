import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';

/// New Download tab. Phase 1 placeholder; Phase 3 builds the single /
/// playlist / multiple-links flows here.
class NewDownloadScreen extends StatelessWidget {
  const NewDownloadScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.link,
      title: context.l10n.titleNewDownload,
      body: context.l10n.newDownloadHint,
    );
  }
}
