import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';

/// Flags library rows whose file was moved or deleted outside the app (and
/// clears the flag when it is back). Returns how many rows changed.
class CheckMissingFilesUseCase {
  CheckMissingFilesUseCase(this._library, this._fs);

  final LibraryRepo _library;
  final FileSystemGateway _fs;

  Future<int> call() async {
    final gone = <String>{};
    final back = <String>{};
    for (final item in await _library.all()) {
      final exists = await _fs.exists(item.path);
      if (!exists && !item.missing) gone.add(item.id);
      if (exists && item.missing) back.add(item.id);
    }
    if (gone.isNotEmpty) await _library.setMissing(gone, missing: true);
    if (back.isNotEmpty) await _library.setMissing(back, missing: false);
    return gone.length + back.length;
  }
}
