import 'dart:io';

import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';

void main() {
  late Directory dir;
  late String file;
  late List<String> runs; // "exe|arg|arg": records compare lists by identity
  var exitCode = 0;
  late _Mobile mobile;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('launcher');
    file = '${dir.path}/Clip - Channel.mp4';
    await File(file).writeAsString('x');
    runs = [];
    exitCode = 0;
    mobile = _Mobile();
  });
  tearDown(() => dir.delete(recursive: true));

  FileLauncher launcher(String os) => FileLauncher(
    operatingSystem: os,
    mobile: mobile,
    run: (exe, args) async {
      runs.add([exe, ...args].join('|'));
      return ProcessResult(0, exitCode, '', 'boom');
    },
  );

  test('macOS: open, and open -R to show it in Finder', () async {
    final l = launcher('macos');
    expect(await l.open(file), isNull);
    expect(await l.reveal(file), isNull);
    expect(runs, ['open|$file', 'open|-R|$file']);
  });

  test('macOS: a failing `open` is reported', () async {
    exitCode = 1;
    expect((await launcher('macos').open(file))?.type, FailureType.unknown);
  });

  test('Windows: explorer, /select, — its exit code is ignored', () async {
    exitCode = 1;
    final l = launcher('windows');
    expect(await l.reveal(file), isNull);
    expect(runs.single, 'explorer.exe|/select,|$file');
  });

  test('a moved or deleted file says so; what each platform can do', () async {
    expect(
      (await launcher('macos').open('${dir.path}/gone.mp4'))?.type,
      FailureType.fileMissing,
    );
    final phone = launcher('android');
    expect(
      (phone.canOpen, phone.canReveal, phone.canSaveToPhotos),
      (true, false, true),
    );
    expect(launcher('linux').canOpen, isFalse);
    expect(runs, isEmpty);
  });

  test('phones: open, share and Save to Photos go to the plugins', () async {
    final phone = launcher('ios');
    expect(await phone.open(file), isNull);
    expect(await phone.share([file]), isNull);
    expect(await phone.saveToPhotos([file]), isNull);
    expect(mobile.calls, ['open|$file', 'share|$file', 'photos|$file']);
    expect(
      (await phone.reveal(file))?.type,
      FailureType.unknown,
      reason: 'no Finder on a phone',
    );
  });

  test('desktop has no Photos; a plugin failure is reported', () async {
    expect(
      (await launcher('macos').saveToPhotos([file]))?.type,
      FailureType.unknown,
    );
    mobile.failure = const AppFailure(type: FailureType.noAppToOpen);
    expect(
      (await launcher('android').open(file))?.type,
      FailureType.noAppToOpen,
    );
  });
}

class _Mobile implements MobileFileApi {
  final calls = <String>[];
  AppFailure? failure;

  @override
  Future<AppFailure?> open(String path) async {
    calls.add('open|$path');
    return failure;
  }

  @override
  Future<void> share(List<String> paths, {Rect? origin}) async =>
      calls.add('share|${paths.join(',')}');

  @override
  Future<AppFailure?> saveVideoToPhotos(String path) async {
    calls.add('photos|$path');
    return failure;
  }
}
