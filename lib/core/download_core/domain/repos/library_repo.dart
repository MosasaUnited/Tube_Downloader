import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/error/result.dart';

/// Finished files. Rows only — deleting a file on disk is FileSystemGateway's.
abstract interface class LibraryRepo {
  Stream<List<LibraryItem>> watch({
    String query = '',
    MediaKind? kind,
    LibrarySort sort = LibrarySort.newest,
  });
  Future<Result<void>> add(LibraryItem item);
  Future<Result<void>> remove(Set<String> ids);
  Future<List<LibraryItem>> all();
  Future<void> setMissing(Set<String> ids, {required bool missing});
}
