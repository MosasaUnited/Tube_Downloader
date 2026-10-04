import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';

/// Classifies pasted text as a video, a playlist or unsupported — offline,
/// before any network call, so the UI can react while typing.
abstract final class LinkParser {
  static final _videoId = RegExp(r'^[A-Za-z0-9_-]{11}$');

  /// YouTube playlist ids: uploads (UU), user lists (PL), albums (OLAK5uy_),
  /// mixes (RD), favourites / likes (FL, LL) and related system lists.
  static final _playlistId = RegExp(
    r'^(PL|UU|FL|RD|OL|LL|UL|PU|EL)[A-Za-z0-9_-]{10,}$',
  );

  static const _hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'music.youtube.com',
    'youtube-nocookie.com',
    'www.youtube-nocookie.com',
  };

  /// Path prefixes whose next segment is a video id.
  static const _videoPaths = {'shorts', 'live', 'embed', 'v', 'e'};

  static ParsedLink parse(String input) {
    final text = input.trim();
    if (text.isEmpty) return ParsedLink.unsupported(input);
    if (_videoId.hasMatch(text)) return _video(text);
    if (_playlistId.hasMatch(text)) return _playlist(text);

    final uri = Uri.tryParse(text.contains('://') ? text : 'https://$text');
    if (uri == null || uri.host.isEmpty) return ParsedLink.unsupported(input);
    final host = uri.host.toLowerCase();
    final list = uri.queryParameters['list'];
    final validList = list != null && _playlistId.hasMatch(list) ? list : null;

    if (host == 'youtu.be') {
      final id = uri.pathSegments.isEmpty ? '' : uri.pathSegments.first;
      return _videoId.hasMatch(id)
          ? _video(id, playlistId: validList)
          : ParsedLink.unsupported(input);
    }
    if (!_hosts.contains(host)) return ParsedLink.unsupported(input);

    final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
    final first = segments.isEmpty ? '' : segments.first;
    if (first == 'watch') {
      final v = uri.queryParameters['v'];
      if (v != null && _videoId.hasMatch(v)) {
        return _video(v, playlistId: validList);
      }
      if (validList != null) return _playlist(validList);
      return ParsedLink.unsupported(input);
    }
    if (first == 'playlist') {
      return validList != null
          ? _playlist(validList)
          : ParsedLink.unsupported(input);
    }
    if (_videoPaths.contains(first) &&
        segments.length > 1 &&
        _videoId.hasMatch(segments[1])) {
      return _video(segments[1], playlistId: validList);
    }
    return ParsedLink.unsupported(input);
  }

  /// The "Multiple links" box: one link per line (spaces also separate),
  /// blank lines ignored, order kept.
  static List<ParsedLink> parseMany(String text) =>
      text.split(RegExp(r'\s+')).where((s) => s.isNotEmpty).map(parse).toList();

  static ParsedLink _video(String id, {String? playlistId}) => ParsedLink.video(
    videoId: id,
    url: 'https://www.youtube.com/watch?v=$id',
    playlistId: playlistId,
  );

  static ParsedLink _playlist(String id) => ParsedLink.playlist(
    playlistId: id,
    url: 'https://www.youtube.com/playlist?list=$id',
  );
}
