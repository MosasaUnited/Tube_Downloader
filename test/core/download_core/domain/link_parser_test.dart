import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/link/link_parser.dart';

String? _video(String input) => switch (LinkParser.parse(input)) {
  ParsedVideo(:final videoId) => videoId,
  _ => null,
};

String? _playlist(String input) => switch (LinkParser.parse(input)) {
  ParsedPlaylist(:final playlistId) => playlistId,
  _ => null,
};

void main() {
  const id = 'R6MlUcmOul8';
  const list = 'PLOU2XLYxmsIJ7ss3D9tXk2Tkk_1h2zNZb';

  test('every video URL shape resolves to the 11-character id', () {
    for (final url in [
      'https://www.youtube.com/watch?v=$id',
      'http://youtube.com/watch?v=$id&t=42s',
      'https://m.youtube.com/watch?v=$id',
      'https://music.youtube.com/watch?v=$id',
      'youtube.com/watch?v=$id',
      'https://youtu.be/$id',
      'https://youtu.be/$id?si=abc',
      'https://www.youtube.com/shorts/$id',
      'https://www.youtube.com/live/$id',
      'https://www.youtube-nocookie.com/embed/$id',
      '  https://youtu.be/$id  ',
      id,
    ]) {
      expect(_video(url), id, reason: url);
    }
  });

  test('a video inside a playlist keeps both ids', () {
    final parsed = LinkParser.parse(
      'https://www.youtube.com/watch?v=$id&list=$list&index=3',
    );
    expect(parsed, isA<ParsedVideo>());
    expect((parsed as ParsedVideo).playlistId, list);
    expect(
      parsed.url,
      'https://www.youtube.com/watch?v=$id',
      reason: 'canonical URL',
    );
  });

  test('playlist URLs and bare playlist ids', () {
    expect(_playlist('https://www.youtube.com/playlist?list=$list'), list);
    expect(_playlist('https://www.youtube.com/watch?list=$list'), list);
    expect(_playlist(list), list);
  });

  test('unsupported input', () {
    for (final input in [
      '',
      'hello world',
      'https://vimeo.com/892401772',
      'https://example.com/watch?v=$id',
      'https://www.youtube.com/watch?v=short',
      'https://www.youtube.com/@channel',
      'https://www.youtube.com/playlist?list=nope',
    ]) {
      expect(LinkParser.parse(input), isA<ParsedUnsupported>(), reason: input);
    }
  });

  test('a batch splits on lines and spaces, keeps order and skips blanks', () {
    final links = LinkParser.parseMany(
      'https://youtu.be/$id\n\n  https://vimeo.com/1 \nhttps://www.youtube.com/playlist?list=$list',
    );
    expect(links.map((l) => l.runtimeType.toString()), [
      'ParsedVideo',
      'ParsedUnsupported',
      'ParsedPlaylist',
    ]);
  });
}
