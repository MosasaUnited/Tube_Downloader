import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/link/link_parser.dart';

part 'link_batch_analyzer.freezed.dart';

/// One link found in the Multiple-links box, classified offline.
@freezed
abstract class BatchEntry with _$BatchEntry {
  const factory BatchEntry({
    /// 1-based order in the box — the row's "#03".
    required int position,

    /// The link as typed (wrapping punctuation removed).
    required String input,
    required ParsedLink link,

    /// Where the token sits in the text, so "remove" can cut it out.
    required int start,
    required int end,

    /// The position of the first entry for the same video or playlist.
    int? duplicateOf,
  }) = _BatchEntry;

  const BatchEntry._();

  String? get videoId => switch (link) {
    ParsedVideo(:final videoId) => videoId,
    _ => null,
  };
}

/// Splits pasted text into links: any whitespace separates them, words that
/// can't be links ("Check", "this:") are ignored, and repeats are marked as
/// duplicates of their first occurrence.
abstract final class LinkBatchAnalyzer {
  /// A pasted document must not turn into thousands of rows.
  static const maxLinks = 200;

  static final _token = RegExp(r'\S+');
  static final _leading = RegExp(r'''^[(<\["']+''');
  static final _trailing = RegExp(r'''[)>\]"',.;:!?]+$''');

  /// host.tld or host.tld/path — a TLD of 2+ letters, so "e.g" isn't one.
  static final _domainLike = RegExp(
    r'^[\w-]+(\.[\w-]+)*\.[a-z]{2,}(/|$)',
    caseSensitive: false,
  );

  static List<BatchEntry> analyze(String text) {
    final firstByKey = <String, int>{};
    final entries = <BatchEntry>[];
    for (final match in _token.allMatches(text)) {
      if (entries.length == maxLinks) break;
      final input = match[0]!
          .replaceFirst(_leading, '')
          .replaceFirst(_trailing, '');
      final link = LinkParser.parse(input);
      if (link is ParsedUnsupported && !_looksLikeLink(input)) continue;
      final position = entries.length + 1;
      final key = switch (link) {
        ParsedVideo(:final videoId) => 'v:$videoId',
        ParsedPlaylist(:final playlistId) => 'p:$playlistId',
        ParsedUnsupported() => null,
      };
      final first = key == null
          ? null
          : firstByKey.putIfAbsent(key, () => position);
      entries.add(
        BatchEntry(
          position: position,
          input: input,
          link: link,
          start: match.start,
          end: match.end,
          duplicateOf: first == position ? null : first,
        ),
      );
    }
    return entries;
  }

  /// [text] without [entries] — each token and the whitespace after it, and
  /// any line left blank. Offsets must come from analyzing this same [text].
  static String remove(String text, Iterable<BatchEntry> entries) {
    final sorted = entries.toList()..sort((a, b) => b.start.compareTo(a.start));
    var result = text;
    for (final e in sorted) {
      var end = e.end;
      while (end < result.length &&
          (result[end] == ' ' || result[end] == '\t')) {
        end++;
      }
      result = result.replaceRange(e.start, end, '');
    }
    return result
        .split('\n')
        .where((line) => line.trim().isNotEmpty)
        .map((line) => line.trimRight())
        .join('\n');
  }

  static bool _looksLikeLink(String input) =>
      input.contains('://') ||
      input.toLowerCase().startsWith('www.') ||
      _domainLike.hasMatch(input);
}
