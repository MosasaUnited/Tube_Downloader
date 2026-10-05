import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/thumbnail_store.dart';
import 'package:tube_downloader/core/error/result.dart';

/// Removes items from the library and — when [fromDisk] — their files and
/// saved thumbnails. Files go first: a row is never dropped while its file
/// failed to delete (the user would lose track of it).
class DeleteLibraryItemsUseCase {
  DeleteLibraryItemsUseCase(this._library, this._fs, this._thumbnails);

  final LibraryRepo _library;
  final FileSystemGateway _fs;
  final ThumbnailStore _thumbnails;

  Future<Result<void>> call(
    List<LibraryItem> items, {
    required bool fromDisk,
  }) async {
    if (fromDisk) {
      for (final item in items) {
        final deleted = await _fs.deletePublished(item.path);
        if (deleted is Failure<void>) return deleted;
      }
    }
    for (final item in items) {
      final thumb = item.thumbPath;
      if (thumb != null) await _thumbnails.delete(thumb);
    }
    return _library.remove({for (final i in items) i.id});
  }
}
