import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// A 16:9 video thumbnail with an optional duration badge: the local copy
/// ([filePath], the library's offline thumbnail) first, then [url], then a
/// neutral placeholder showing [placeholderIcon]. Images are decoded at the
/// size they are shown (performance skill: cacheWidth).
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    required this.url,
    this.width,
    this.decodeWidthHint = 320,
    this.filePath,
    this.duration,
    this.radius = Dimens.radiusButton,
    this.placeholderIcon = Icons.movie_outlined,
    super.key,
  });

  final String? url;
  final String? filePath;

  /// null = fill the width it is given (grid cards; no LayoutBuilder, so it
  /// works inside IntrinsicHeight). [decodeWidthHint] then sizes the decode.
  final double? width;
  final double decodeWidthHint;
  final Duration? duration;
  final double radius;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final decodeWidth =
        ((width ?? decodeWidthHint) * MediaQuery.devicePixelRatioOf(context))
            .round();
    final placeholder = ColoredBox(
      color: colors.surfaceRaised,
      child: Center(child: Icon(placeholderIcon, color: colors.textMuted)),
    );
    final network = url == null
        ? placeholder
        : Image.network(
            url!,
            fit: BoxFit.cover,
            cacheWidth: decodeWidth,
            errorBuilder: (_, _, _) => placeholder,
            frameBuilder: (_, child, frame, wasSync) =>
                wasSync || frame != null ? child : placeholder,
          );
    final local = filePath;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (local == null)
                network
              else
                Image.file(
                  File(local),
                  fit: BoxFit.cover,
                  cacheWidth: decodeWidth,
                  // Deleted cache: the network copy, then the placeholder.
                  errorBuilder: (_, _, _) => network,
                ),
              if (duration != null)
                PositionedDirectional(
                  end: Dimens.space4,
                  bottom: Dimens.space4,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: ColorsManager.thumbnailBadge,
                      borderRadius: BorderRadius.circular(Dimens.space4),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: Dimens.space4,
                        vertical: 1,
                      ),
                      child: Text(
                        formatDuration(duration!),
                        style: Styles.font12Bold.copyWith(
                          color: ColorsManager.white,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
