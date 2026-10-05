import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';

void main() {
  late Directory dir;
  late String file;
  late List<String> runs; // "exe|arg|arg": records compare lists by identity
  var exitCode = 0;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('launcher');
    file = '${dir.path}/Clip - Channel.mp4';
    await File(file).writeAsString('x');
    runs = [];
    exitCode = 0;
  });
  tearDown(() => dir.delete(recursive: true));

  FileLauncher launcher(String os) => FileLauncher(
    operatingSystem: os,
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

  test(
    'a moved or deleted file says so; phones are not supported yet',
    () async {
      expect(
        (await launcher('macos').open('${dir.path}/gone.mp4'))?.type,
        FailureType.fileMissing,
      );
      expect(launcher('android').isSupported, isFalse);
      expect(runs, isEmpty);
    },
  );
}
