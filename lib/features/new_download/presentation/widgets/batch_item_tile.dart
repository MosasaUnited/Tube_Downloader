import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/helpers/breakpoints.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/ltr_text.dart';
import 'package:tube_downloader/core/widgets/media_thumbnail.dart';
import 'package:tube_downloader/core/widgets/status_chip.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_cubit.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_state.dart';
import 'package:tube_downloader/features/new_download/logic/link_input_cubit/link_input_cubit.dart';
import 'package:tube_downloader/features/new_download/presentation/widgets/quality_dropdown.dart';

/// One row of "Resolved items": thumbnail (or a status icon), title or the
/// raw link, a status line, the status chip, its own quality (wide windows,
/// ready rows) and remove. On phones the row also swipes away.
class BatchItemTile extends StatelessWidget {
  const BatchItemTile({
    required this.item,
    required this.kind,
    required this.estimate,
    super.key,
  });

  final BatchItem item;
  final MediaKind kind;
  final int? estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<BatchLinksCubit>();
    final compact = windowClassOf(context) == WindowClass.compact;
    final videoId = item.videoId;
    final media = item.media;
    final card = Opacity(
      opacity: item.status == BatchItemStatus.duplicate ? 0.6 : 1,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(Dimens.space8),
          child: Row(
            children: [
              if (media != null)
                MediaThumbnail(
                  url: media.thumbnailUrl,
                  width: compact ? 96 : 128,
                  duration: media.duration,
                )
              else
                _StatusTile(status: item.status, width: compact ? 96 : 128),
              horizontalSpace(Dimens.space12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Title(item: item),
                    verticalSpace(Dimens.space4),
                    _Detail(item: item, estimate: estimate),
                    if (compact) ...[
                      verticalSpace(Dimens.space8),
                      _Chip(item: item),
                    ],
                  ],
                ),
              ),
              if (!compact) ...[
                horizontalSpace(Dimens.space12),
                _Chip(item: item),
              ],
              if (!compact &&
                  item.status == BatchItemStatus.ready &&
                  videoId != null) ...[
                horizontalSpace(Dimens.space12),
                QualityDropdown(
                  kind: kind,
                  value: context.select(
                    (BatchLinksCubit c) => c.state.overrides[videoId],
                  ),
                  defaultLabel: l10n.qualityDefault,
                  onChanged: (f) => cubit.setOverride(videoId, f),
                ),
              ],
              IconButton(
                tooltip: l10n.actionRemove,
                onPressed: () => cubit.remove(item.position),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
    if (!compact) return card;
    return Dismissible(
      key: ValueKey('dismiss-${item.position}-${item.input}'),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => cubit.remove(item.position),
      background: const _DismissBackground(),
      child: card,
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.item});

  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final title = item.media?.title;
    final style = Styles.font14Bold.copyWith(color: colors.textPrimary);
    if (title != null) {
      return Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final failed =
        item.status == BatchItemStatus.invalid ||
        item.status == BatchItemStatus.failed;
    return LtrText(
      item.input,
      style: style.copyWith(color: failed ? ColorsManager.error : null),
    );
  }
}

/// The line under the title: what the status means for this row.
class _Detail extends StatelessWidget {
  const _Detail({required this.item, required this.estimate});

  final BatchItem item;
  final int? estimate;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = context.colors;
    final muted = Styles.font12Regular.copyWith(color: colors.textSecondary);
    final failure = item.failure;
    return switch (item.status) {
      BatchItemStatus.ready => Text(
        [
          ?item.media?.channel,
          if (item.media?.duration case final duration?)
            formatDuration(duration),
          if (estimate case final bytes?)
            l10n.approximately(formatBytes(bytes)),
        ].join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: muted,
      ),
      BatchItemStatus.resolving => Text(
        l10n.fetchingDetails,
        style: Styles.font12Regular.copyWith(color: ColorsManager.accent),
      ),
      BatchItemStatus.invalid => Text(
        l10n.batchInvalidHint,
        style: Styles.font12Regular.copyWith(color: ColorsManager.error),
      ),
      BatchItemStatus.duplicate => Text(
        l10n.batchDuplicateOf(formatPlaylistIndex(item.duplicateOf ?? 0)),
        style: muted,
      ),
      BatchItemStatus.playlist => _ActionLine(
        text: l10n.batchPlaylistHint,
        actionLabel: l10n.batchOpenPlaylist,
        onAction: () => context.read<LinkInputCubit>().open(item.input),
      ),
      BatchItemStatus.failed => _ActionLine(
        text: failure == null
            ? l10n.failureUnknown
            : failureMessage(context, failure),
        color: ColorsManager.error,
        actionLabel: item.canRetry ? l10n.actionRetry : null,
        onAction: () => context.read<BatchLinksCubit>().retry(item.videoId!),
      ),
    };
  }
}

class _ActionLine extends StatelessWidget {
  const _ActionLine({
    required this.text,
    required this.onAction,
    this.actionLabel,
    this.color,
  });

  final String text;
  final String? actionLabel;
  final VoidCallback onAction;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final label = actionLabel;
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Dimens.space8,
      children: [
        Text(
          text,
          style: Styles.font12Regular.copyWith(
            color: color ?? context.colors.textSecondary,
          ),
        ),
        if (label != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: Dimens.space8),
            ),
            child: Text(label),
          ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.item});

  final BatchItem item;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (item.status) {
      BatchItemStatus.resolving => StatusChip(
        label: l10n.batchStatusResolving,
        color: ColorsManager.accent,
        busy: true,
      ),
      BatchItemStatus.ready => StatusChip(
        label: l10n.batchStatusReady,
        color: ColorsManager.success,
        icon: Icons.check_circle_outline,
      ),
      BatchItemStatus.invalid => StatusChip(
        label: l10n.batchStatusInvalid,
        color: ColorsManager.error,
        icon: Icons.link_off,
      ),
      BatchItemStatus.duplicate => StatusChip(
        label: l10n.batchStatusDuplicate,
        color: ColorsManager.warning,
        icon: Icons.copy_all_outlined,
      ),
      BatchItemStatus.playlist => StatusChip(
        label: l10n.newDownloadTabPlaylist,
        color: ColorsManager.primary,
        icon: Icons.playlist_play,
      ),
      BatchItemStatus.failed => StatusChip(
        label: l10n.batchStatusFailed,
        color: ColorsManager.error,
        icon: Icons.error_outline,
      ),
    };
  }
}

/// The thumbnail's place while there is no thumbnail.
class _StatusTile extends StatelessWidget {
  const _StatusTile({required this.status, required this.width});

  final BatchItemStatus status;
  final double width;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (icon, color) = switch (status) {
      BatchItemStatus.resolving => (Icons.sync, ColorsManager.accent),
      BatchItemStatus.invalid => (Icons.link_off, ColorsManager.error),
      BatchItemStatus.failed => (Icons.error_outline, ColorsManager.error),
      BatchItemStatus.playlist => (Icons.playlist_play, ColorsManager.primary),
      BatchItemStatus.duplicate => (
        Icons.copy_all_outlined,
        ColorsManager.warning,
      ),
      BatchItemStatus.ready => (Icons.movie_outlined, colors.textMuted),
    };
    return SizedBox(
      width: width,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surfaceRaised,
            borderRadius: BorderRadius.circular(Dimens.radiusButton),
          ),
          child: Icon(icon, color: color),
        ),
      ),
    );
  }
}

class _DismissBackground extends StatelessWidget {
  const _DismissBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: ColorsManager.error.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(Dimens.radiusCard),
      ),
      child: const Align(
        alignment: AlignmentDirectional.centerEnd,
        child: Padding(
          padding: EdgeInsetsDirectional.only(end: Dimens.space24),
          child: Icon(Icons.delete_outline, color: ColorsManager.error),
        ),
      ),
    );
  }
}
