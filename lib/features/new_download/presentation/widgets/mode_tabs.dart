import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_state.dart';

/// Single video · Playlist · Multiple links.
class ModeTabs extends StatelessWidget {
  const ModeTabs({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final mode = context.select((LinkInputCubit c) => c.state.mode);
    return SegmentedButton<NewDownloadMode>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: NewDownloadMode.single,
          icon: const Icon(Icons.smart_display_outlined),
          label: Text(l10n.newDownloadTabSingle),
        ),
        ButtonSegment(
          value: NewDownloadMode.playlist,
          icon: const Icon(Icons.playlist_play),
          label: Text(l10n.newDownloadTabPlaylist),
        ),
        ButtonSegment(
          value: NewDownloadMode.multiple,
          icon: const Icon(Icons.format_list_bulleted),
          label: Text(l10n.newDownloadTabMultiple),
        ),
      ],
      selected: {mode},
      onSelectionChanged: (s) =>
          context.read<LinkInputCubit>().setMode(s.single),
    );
  }
}
