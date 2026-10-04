import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/features/new_download/domain/link_batch_analyzer.dart';

void main() {
  group('analyze', () {
    test('any whitespace separates links; order and positions kept', () {
      final entries = LinkBatchAnalyzer.analyze(
        '  https://youtu.be/R6MlUcmOul8\n\n'
        'https://www.youtube.com/watch?v=aqz-KE-bpKQ\thttps://youtu.be/eRsGyueVLvQ  ',
      );
      expect(entries.map((e) => (e.position, e.videoId)), [
        (1, 'R6MlUcmOul8'),
        (2, 'aqz-KE-bpKQ'),
        (3, 'eRsGyueVLvQ'),
      ]);
    });

    test('wrapping punctuation from chats and documents is dropped', () {
      final entries = LinkBatchAnalyzer.analyze(
        '(https://youtu.be/R6MlUcmOul8), <https://youtu.be/aqz-KE-bpKQ>. '
        '"https://youtu.be/eRsGyueVLvQ"',
      );
      expect(entries.map((e) => e.videoId), [
        'R6MlUcmOul8',
        'aqz-KE-bpKQ',
        'eRsGyueVLvQ',
      ]);
      expect(entries.first.input, 'https://youtu.be/R6MlUcmOul8');
    });

    test('prose is ignored; link-like text that is not YouTube is invalid', () {
      final entries = LinkBatchAnalyzer.analyze(
        'Watch these: https://youtu.be/R6MlUcmOul8 and also '
        'https://example.com/invalid-stream/99 vimeo.com/892401772 www.foo.org e.g.',
      );
      expect(entries.map((e) => (e.input, e.link is ParsedUnsupported)), [
        ('https://youtu.be/R6MlUcmOul8', false),
        ('https://example.com/invalid-stream/99', true),
        ('vimeo.com/892401772', true),
        ('www.foo.org', true),
      ]);
    });

    test('the same video in any URL form is a duplicate of the first', () {
      final entries = LinkBatchAnalyzer.analyze('''
https://www.youtube.com/watch?v=R6MlUcmOul8
https://www.youtube.com/playlist?list=PLabcdefghij12
https://youtu.be/R6MlUcmOul8?t=30
https://m.youtube.com/shorts/R6MlUcmOul8
https://youtube.com/playlist?list=PLabcdefghij12
''');
      expect(entries.map((e) => e.duplicateOf), [null, null, 1, 1, 2]);
    });

    test('invalid lines are never duplicates of each other', () {
      final entries = LinkBatchAnalyzer.analyze(
        'https://example.com/a\nhttps://example.com/a',
      );
      expect(entries.map((e) => e.duplicateOf), [null, null]);
    });

    test('a pasted document is capped at maxLinks rows', () {
      final text = List.filled(
        LinkBatchAnalyzer.maxLinks + 50,
        'https://example.com/x',
      ).join('\n');
      expect(
        LinkBatchAnalyzer.analyze(text),
        hasLength(LinkBatchAnalyzer.maxLinks),
      );
    });
  });

  group('remove', () {
    const text =
        'https://youtu.be/R6MlUcmOul8\n'
        'https://youtu.be/aqz-KE-bpKQ https://youtu.be/eRsGyueVLvQ\n'
        'https://example.com/bad\n';

    BatchEntry at(int position) =>
        LinkBatchAnalyzer.analyze(text)[position - 1];

    test('a link alone on its line takes the line with it', () {
      expect(
        LinkBatchAnalyzer.remove(text, [at(1)]),
        'https://youtu.be/aqz-KE-bpKQ https://youtu.be/eRsGyueVLvQ\n'
        'https://example.com/bad',
      );
    });

    test('a link sharing its line leaves the others', () {
      expect(
        LinkBatchAnalyzer.remove(text, [at(2)]),
        'https://youtu.be/R6MlUcmOul8\n'
        'https://youtu.be/eRsGyueVLvQ\n'
        'https://example.com/bad',
      );
    });

    test('several at once (any order) — offsets stay valid', () {
      expect(
        LinkBatchAnalyzer.remove(text, [at(1), at(4), at(3)]),
        'https://youtu.be/aqz-KE-bpKQ',
      );
      expect(LinkBatchAnalyzer.remove(text, [at(1), at(2), at(3), at(4)]), '');
    });
  });
}
