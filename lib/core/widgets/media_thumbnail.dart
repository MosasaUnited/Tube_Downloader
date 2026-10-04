import 'package:flutter/material.dart';
import 'package:tube_downloader/core/helpers/formatters.dart';
import 'package:tube_downloader/core/theme/app_colors.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:tube_downloader/core/theme/dimens.dart';
import 'package:tube_downloader/core/theme/styles.dart';

/// A 16:9 video thumbnail with an optional duration badge. Network images are
/// decoded at the size they are shown (performance skill: cacheWidth), and a
/// missing or failed image falls back to a neutral placeholder.
class MediaThumbnail extends StatelessWidget {
  const MediaThumbnail({
    required this.url,
    required this.width,
    this.duration,
    this.radius = Dimens.radiusButton,
    super.key,
  });

  final String? url;
  final double width;
  final Duration? duration;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final decodeWidth = (width * MediaQuery.devicePixelRatioOf(context))
        .round();
    final placeholder = ColoredBox(
      color: colors.surfaceRaised,
      child: Center(child: Icon(Icons.movie_outlined, color: colors.textMuted)),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: SizedBox(
        width: width,
        child: AspectRatio(
          aspectRatio: 16 / 9,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (url == null)
                placeholder
              else
                Image.network(
                  url!,
                  fit: BoxFit.cover,
                  cacheWidth: decodeWidth,
                  errorBuilder: (_, _, _) => placeholder,
                  frameBuilder: (_, child, frame, wasSync) =>
                      wasSync || frame != null ? child : placeholder,
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
