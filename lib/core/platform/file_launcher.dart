import 'dart:io';
import 'dart:ui';

import 'package:gal/gal.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/failure_type.dart';

typedef ProcessRunner = Future<ProcessResult> Function(
  String executable,
  List<String> arguments,
);

/// The plugin calls behind [FileLauncher] on phones (a seam for tests).
abstract interface class MobileFileApi {
  /// The failure to report, or null when the file opened.
  Future<AppFailure?> open(String path);
  Future<void> share(List<String> paths, {Rect? origin});
  Future<AppFailure?> saveVideoToPhotos(String path);
}

/// What the app can do with a finished file: open it with its default app,
/// show it in Finder / File Explorer (desktop), share it, or save a video to
/// Photos (phones). Every action returns the failure to report, null when it
/// worked.
class FileLauncher {
  FileLauncher({
    ProcessRunner? run,
    String? operatingSystem,
    MobileFileApi? mobile,
  }) : _run = run ?? Process.run,
       _os = operatingSystem ?? Platform.operatingSystem,
       _mobile = mobile ?? const _PluginFileApi();

  final ProcessRunner _run;
  final String _os;
  final MobileFileApi _mobile;

  bool get _desktop => _os == 'macos' || _os == 'windows';
  bool get _phone => _os == 'ios' || _os == 'android';

  bool get canOpen => _desktop || _phone;
  bool get canReveal => _desktop;
  bool get canSaveToPhotos => _phone;

  Future<AppFailure?> open(String path) => _guard(path, () async {
    if (_phone) return _mobile.open(path);
    return _desktopLaunch(path, reveal: false);
  });

  Future<AppFailure?> reveal(String path) => _guard(path, () async {
    if (!_desktop) return const AppFailure(type: FailureType.unknown);
    return _desktopLaunch(path, reveal: true);
  });

  /// The system share sheet. [origin] anchors it on iPad (required there).
  Future<AppFailure?> share(List<String> paths, {Rect? origin}) async {
    try {
      for (final path in paths) {
        if (!await File(path).exists()) {
          return const AppFailure(type: FailureType.fileMissing);
        }
      }
      await _mobile.share(paths, origin: origin);
      return null;
    } on Object catch (e, s) {
      return FailureMapper.map(e, s);
    }
  }

  /// Videos only (Photos takes no audio); stops at the first failure.
  Future<AppFailure?> saveToPhotos(List<String> paths) async {
    if (!_phone) return const AppFailure(type: FailureType.unknown);
    for (final path in paths) {
      final failure = await _guard(path, () => _mobile.saveVideoToPhotos(path));
      if (failure != null) return failure;
    }
    return null;
  }

  Future<AppFailure?> _guard(
    String path,
    Future<AppFailure?> Function() action,
  ) async {
    if (!canOpen) return const AppFailure(type: FailureType.unknown);
    try {
      if (!await File(path).exists()) {
        return const AppFailure(type: FailureType.fileMissing);
      }
      return await action();
    } on Object catch (e, s) {
      return FailureMapper.map(e, s);
    }
  }

  Future<AppFailure?> _desktopLaunch(
    String path, {
    required bool reveal,
  }) async {
    if (_os == 'macos') {
      final result = await _run('open', [if (reveal) '-R', path]);
      return result.exitCode == 0
          ? null
          : AppFailure(type: FailureType.unknown, debug: '${result.stderr}');
    }
    // explorer.exe exits with 1 even when it worked: its code means nothing.
    await _run('explorer.exe', [if (reveal) '/select,', path]);
    return null;
  }
}

/// open_filex, share_plus and gal.
class _PluginFileApi implements MobileFileApi {
  const _PluginFileApi();

  @override
  Future<AppFailure?> open(String path) async {
    final result = await OpenFilex.open(path);
    return switch (result.type) {
      ResultType.done => null,
      ResultType.fileNotFound => const AppFailure(
        type: FailureType.fileMissing,
      ),
      ResultType.noAppToOpen => const AppFailure(type: FailureType.noAppToOpen),
      ResultType.permissionDenied => const AppFailure(
        type: FailureType.permissionDenied,
      ),
      ResultType.error => AppFailure(
        type: FailureType.unknown,
        debug: result.message,
      ),
    };
  }

  @override
  Future<void> share(List<String> paths, {Rect? origin}) =>
      SharePlus.instance.share(
        ShareParams(
          files: [for (final p in paths) XFile(p)],
          sharePositionOrigin: origin,
        ),
      );

  @override
  Future<AppFailure?> saveVideoToPhotos(String path) async {
    if (!await Gal.hasAccess() && !await Gal.requestAccess()) {
      return const AppFailure(type: FailureType.permissionDenied);
    }
    try {
      await Gal.putVideo(path);
      return null;
    } on GalException catch (e) {
      return AppFailure(
        type: switch (e.type) {
          GalExceptionType.accessDenied => FailureType.permissionDenied,
          GalExceptionType.notEnoughSpace => FailureType.storageFull,
          _ => FailureType.unknown,
        },
        debug: e.type.name,
      );
    }
  }
}
