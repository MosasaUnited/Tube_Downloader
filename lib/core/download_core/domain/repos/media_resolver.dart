import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/entities/stream_target.dart';
import 'package:tube_downloader/core/error/result.dart';

/// Turns links into metadata and fetchable streams. The YouTube
/// implementation is the only class that knows youtube_explode_dart; a desktop
/// yt-dlp resolver can replace it behind this contract (Strategy).
abstract interface class MediaResolver {
  Future<Result<ResolvedLink>> resolve(ParsedLink link);

  /// Playlist items in order. A failure item ends the stream.
  Stream<Result<MediaInfo>> playlistItems(String playlistId);

  /// The quality picker's rows for one video.
  Future<Result<List<FormatOption>>> formats(String videoId);

  /// Which legs [selector] needs for this video: video + audio (merge),
  /// audio only, or one muxed leg when no separate streams exist.
  Future<Result<List<LegKind>>> plan(String videoId, FormatSelector selector);

  /// A FRESH stream for one leg, resolved right before it downloads (URLs
  /// expire and are bound to the IP address).
  Future<Result<StreamTarget>> target(
    String videoId,
    FormatSelector selector,
    LegKind leg,
  );

  void close();
}
