import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/result.dart';

/// The system folder chooser for Settings › Save location. Desktop only:
/// iOS keeps downloads in the app's Documents (the Files app), Android
/// publishes them to Movies / Music through MediaStore.
class FolderPicker {
  bool get isSupported => !Platform.isIOS && !Platform.isAndroid;

  /// The chosen folder; success(null) when the user cancels.
  Future<Result<String?>> pick({String? initialDirectory}) async {
    try {
      return Result.success(
        await FilePicker.getDirectoryPath(initialDirectory: initialDirectory),
      );
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }
}
