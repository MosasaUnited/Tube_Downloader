import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/widgets/empty_state.dart';

/// Library tab. Phase 1 shows the empty state; Phase 5 adds the grid.
class LibraryScreen extends StatelessWidget {
  const LibraryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.video_library_outlined,
      title: context.l10n.emptyLibraryTitle,
      body: context.l10n.emptyLibraryBody,
    );
  }
}
