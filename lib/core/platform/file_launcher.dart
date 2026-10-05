import 'dart:io';

import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/failure_type.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// Opens a finished file with its default app, or shows it selected in
/// Finder / File Explorer. Desktop only for now (phones get `open_filex` with
/// the Library, Phase 5). Returns the failure to report, null on success.
class FileLauncher {
  FileLauncher({ProcessRunner? run, String? operatingSystem})
    : _run = run ?? Process.run,
      _os = operatingSystem ?? Platform.operatingSystem;

  final ProcessRunner _run;
  final String _os;

  bool get isSupported => _os == 'macos' || _os == 'windows';

  Future<AppFailure?> open(String path) => _launch(path, reveal: false);

  Future<AppFailure?> reveal(String path) => _launch(path, reveal: true);

  Future<AppFailure?> _launch(String path, {required bool reveal}) async {
    if (!isSupported) return const AppFailure(type: FailureType.unknown);
    try {
      if (!await File(path).exists()) {
        return const AppFailure(type: FailureType.fileMissing);
      }
      if (_os == 'macos') {
        final result = await _run('open', [if (reveal) '-R', path]);
        return result.exitCode == 0
            ? null
            : AppFailure(type: FailureType.unknown, debug: '${result.stderr}');
      }
      // explorer.exe exits with 1 even when it worked: its code means nothing.
      await _run('explorer.exe', [if (reveal) '/select,', path]);
      return null;
    } on Object catch (e, s) {
      return FailureMapper.map(e, s);
    }
  }
}
