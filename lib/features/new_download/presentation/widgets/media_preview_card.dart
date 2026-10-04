import 'package:flutter/material.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/spacing.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';
import 'package:tube_downloader/core/widgets/media_thumbnail.dart';

/// Thumbnail, title, channel and views of the fetched video.
class MediaPreviewCard extends StatelessWidget {
  const MediaPreviewCard({required this.media, super.key});

  final MediaInfo media;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final views = media.viewCount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(Dimens.space16),
        child: LayoutBuilder(
          builder: (context, constraints) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MediaThumbnail(
                url: media.thumbnailUrl,
                width: constraints.maxWidth,
                duration: media.duration,
              ),
              verticalSpace(Dimens.space16),
              Text(
                media.title,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Styles.font20Bold.copyWith(color: colors.textPrimary),
              ),
              verticalSpace(Dimens.space8),
              Text(
                media.channel,
                style: Styles.font14Bold.copyWith(color: colors.textSecondary),
              ),
              if (views != null)
                Text(
                  context.l10n.mediaViews(formatCompactCount(views)),
                  style: Styles.font12Regular.copyWith(color: colors.textMuted),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
