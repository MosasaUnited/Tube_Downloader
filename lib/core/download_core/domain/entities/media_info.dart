import 'package:freezed_annotation/freezed_annotation.dart';

part 'media_info.freezed.dart';

/// One video as the resolver describes it. Plain metadata — no stream URLs.
@freezed
abstract class MediaInfo with _$MediaInfo {
  const factory MediaInfo({
    required String videoId,

    /// Canonical watch URL (for "Copy link").
    required String url,
    required String title,
    required String channel,
    Duration? duration,
    String? thumbnailUrl,
    @Default(false) bool isLive,
    int? viewCount,
    DateTime? uploadDate,
  }) = _MediaInfo;
}

/// A playlist header; its items stream separately (they can be hundreds).
@freezed
abstract class PlaylistInfo with _$PlaylistInfo {
  const factory PlaylistInfo({
    required String playlistId,
    required String url,
    required String title,
    String? channel,
    int? videoCount,
    String? thumbnailUrl,
  }) = _PlaylistInfo;
}

/// What a pasted link turned out to be.
@freezed
sealed class ResolvedLink with _$ResolvedLink {
  const factory ResolvedLink.single(MediaInfo media) = ResolvedSingle;
  const factory ResolvedLink.playlist(PlaylistInfo playlist) = ResolvedPlaylist;
}
