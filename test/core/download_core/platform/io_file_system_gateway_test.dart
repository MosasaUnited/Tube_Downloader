import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/platform/io_file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/data/platform/media_publisher.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/error/result.dart';

void main() {
  late Directory root;
  late AppDatabase db;
  late SettingsRepoImpl settings;
  late IoFileSystemGateway fs;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('fs_gateway');
    db = AppDatabase(NativeDatabase.memory());
    settings = SettingsRepoImpl(db);
    await settings.load();
    fs = IoFileSystemGateway(
      settings,
      supportDirectory: () async => Directory('${root.path}/support'),
      defaultSaveDirectory: () async =>
          Directory('${root.path}/Downloads/Tube Downloader'),
    );
  });

  tearDown(() async {
    await db.close();
    await root.delete(recursive: true);
  });

  Future<String> partial(String taskId, String name, int bytes) async {
    final path = '${await fs.workDir(taskId)}/$name';
    await File(path).writeAsBytes(List.filled(bytes, 7));
    return path;
  }

  test('work folders: create, list, measure, delete', () async {
    final path = await partial('t1', 'video.part', 42);
    expect(await fs.fileLength(path), 42);
    expect(await fs.fileLength('${root.path}/missing'), 0);
    expect(await fs.workDirTaskIds(), ['t1']);
    await fs.deleteWorkDir('t1');
    expect(await fs.workDirTaskIds(), isEmpty);
  });

  test(
    'Android: publish hands the file to MediaStore (no folder chosen)',
    () async {
      final media = _FakeMediaPublisher();
      final android = IoFileSystemGateway(
        settings,
        supportDirectory: () async => Directory('${root.path}/support'),
        defaultSaveDirectory: () async => Directory('${root.path}/Documents'),
        mediaPublisher: media,
      );
      final source = await partial('t1', 'out.mp4', 10);
      final result = await android.publish(
        sourcePath: source,
        fileName: 'Clip.mp4',
        subDir: 'Mix',
      );
      expect(
        (result as Success<String>).data,
        '/storage/Movies/Tube Downloader/Mix/Clip.mp4',
      );
      expect(media.calls, ['$source|Clip.mp4|Mix']);

      media.fail = true;
      final failed = await android.publish(
        sourcePath: source,
        fileName: 'Clip.mp4',
      );
      expect(
        failed,
        isA<Failure<String>>(),
        reason: 'a channel error is a failure',
      );
    },
  );

  test('publish moves into the default folder and never overwrites', () async {
    final first = await fs.publish(
      sourcePath: await partial('t1', 'out.mp4', 10),
      fileName: 'Clip.mp4',
    );
    final second = await fs.publish(
      sourcePath: await partial('t2', 'out.mp4', 20),
      fileName: 'Clip.mp4',
    );

    final a = (first as Success<String>).data;
    final b = (second as Success<String>).data;
    expect(a, '${root.path}/Downloads/Tube Downloader/Clip.mp4');
    expect(b, '${root.path}/Downloads/Tube Downloader/Clip (2).mp4');
    expect(File(a).lengthSync(), 10);
    expect(File(b).lengthSync(), 20);
  });

  test(
    'publish honours the save folder from Settings and the playlist subfolder',
    () async {
      await settings.update(
        (s) => s.copyWith(saveDirectory: '${root.path}/Videos'),
      );
      final result = await fs.publish(
        sourcePath: await partial('t1', 'out.mp3', 5),
        fileName: '01 - Intro.mp3',
        subDir: 'Lo-fi',
      );
      expect(
        (result as Success<String>).data,
        '${root.path}/Videos/Lo-fi/01 - Intro.mp3',
      );
    },
  );

  test('a missing source is a failure, not an exception', () async {
    final result = await fs.publish(
      sourcePath: '${root.path}/nope.part',
      fileName: 'x.mp4',
    );
    expect(result, isA<Failure<String>>());
  });
}

class _FakeMediaPublisher implements MediaPublisher {
  final calls = <String>[];
  var fail = false;

  @override
  Future<String> publish({
    required String sourcePath,
    required String fileName,
    String? subDir,
  }) async {
    if (fail) throw StateError('MediaStore insert failed');
    calls.add('$sourcePath|$fileName|$subDir');
    return '/storage/Movies/Tube Downloader/$subDir/$fileName';
  }
}
