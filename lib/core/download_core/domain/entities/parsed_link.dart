import 'package:freezed_annotation/freezed_annotation.dart';

part 'parsed_link.freezed.dart';

/// A pasted string, classified WITHOUT a network call (LinkParser).
@freezed
sealed class ParsedLink with _$ParsedLink {
  /// A single video. [playlistId] is set for `watch?v=…&list=…` so the UI can
  /// offer "download the whole playlist".
  const factory ParsedLink.video({
    required String videoId,
    required String url,
    String? playlistId,
  }) = ParsedVideo;
  const factory ParsedLink.playlist({
    required String playlistId,
    required String url,
  }) = ParsedPlaylist;
  const factory ParsedLink.unsupported(String input) = ParsedUnsupported;
}
