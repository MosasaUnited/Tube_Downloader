import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/format_chip.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_state.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/quality_dropdown.dart';

/// "Resolved items (N)" · Video/Audio · Default quality. Wide windows: one
/// wrapping line. Phones: stacked, the Video/Audio switch full width.
class BatchToolbar extends StatelessWidget {
  const BatchToolbar({required this.state, super.key});

  final BatchLinksState state;

  @override
  Widget build(BuildContext context) {
    final title = _Title(count: state.items.length);
    final kind = _KindSwitch(kind: state.kind);
    final compact = windowClassOf(context) == WindowClass.compact;
    final quality = _DefaultQuality(state: state, compact: compact);
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          title,
          verticalSpace(Dimens.space12),
          kind,
          verticalSpace(Dimens.space12),
          quality,
        ],
      );
    }
    return Wrap(
      alignment: WrapAlignment.spaceBetween,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Dimens.space16,
      runSpacing: Dimens.space12,
      children: [
        title,
        Wrap(
          spacing: Dimens.space12,
          runSpacing: Dimens.space8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [kind, quality],
        ),
      ],
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.l10n.batchResolvedItems,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Styles.font20Bold.copyWith(
              color: context.colors.textPrimary,
            ),
          ),
        ),
        horizontalSpace(Dimens.space8),
        FormatChip('$count'),
      ],
    );
  }
}

class _KindSwitch extends StatelessWidget {
  const _KindSwitch({required this.kind});

  final MediaKind kind;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<MediaKind>(
      showSelectedIcon: false,
      segments: [
        ButtonSegment(
          value: MediaKind.video,
          icon: const Icon(Icons.videocam_outlined),
          label: Text(l10n.formatVideoAudio),
        ),
        ButtonSegment(
          value: MediaKind.audio,
          icon: const Icon(Icons.music_note_outlined),
          label: Text(l10n.formatAudioOnly),
        ),
      ],
      selected: {kind},
      onSelectionChanged: (s) =>
          context.read<BatchLinksCubit>().setKind(s.single),
    );
  }
}

/// Phones: the label and the dropdown share the full width (the dropdown
/// ellipsizes at large text sizes). Wide windows: natural width.
class _DefaultQuality extends StatelessWidget {
  const _DefaultQuality({required this.state, required this.compact});

  final BatchLinksState state;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final dropdown = QualityDropdown(
      kind: state.kind,
      value: state.format,
      expanded: compact,
      onChanged: (f) {
        if (f != null) context.read<BatchLinksCubit>().setFormat(f);
      },
    );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: Text(
            context.l10n.batchDefaultQuality,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Styles.font14Regular.copyWith(
              color: context.colors.textSecondary,
            ),
          ),
        ),
        horizontalSpace(Dimens.space8),
        if (compact) Expanded(child: dropdown) else dropdown,
      ],
    );
  }
}
