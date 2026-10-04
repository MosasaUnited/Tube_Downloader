import 'dart:convert';

import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:tube_downloader/core/download_core/domain/link/link_file_extractor.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/result.dart';

/// Reads links from files: a `.txt` list picked with the system dialog, or
/// `.txt` / `.webloc` / `.url` files dropped on the window. A class (not
/// static calls) so cubits can be tested with a fake.
class LinkFileReader {
  /// Only the start of a huge file is read: 256 KB is thousands of links,
  /// far past [LinkBatchAnalyzer.maxLinks].
  static const _maxBytes = 256 * 1024;

  /// The text of the `.txt` file the user picks; success(null) on cancel.
  Future<Result<String?>> pickText() async {
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['txt'],
      );
      if (file == null) return const Result.success(null);
      return Result.success(
        LinkFileExtractor.extract(file.name, await _read(file.xFile)),
      );
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  /// The links in [files], one file per line. Unsupported and unreadable
  /// files are skipped: a drop of mixed files keeps what it can use.
  Future<String> readDropped(List<XFile> files) async {
    final parts = <String>[];
    for (final file in files) {
      if (!LinkFileExtractor.supports(file.name)) continue;
      try {
        final links = LinkFileExtractor.extract(file.name, await _read(file));
        if (links != null) parts.add(links);
      } on Object catch (e, s) {
        FailureMapper.map(e, s); // logged; the other files still count
      }
    }
    return parts.join('\n');
  }

  Future<String> _read(XFile file) async {
    final bytes = <int>[];
    await file.openRead(0, _maxBytes).forEach(bytes.addAll);
    return utf8.decode(bytes, allowMalformed: true);
  }
}
