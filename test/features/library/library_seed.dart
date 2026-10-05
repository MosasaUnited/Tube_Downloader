import 'dart:io';

import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';

/// Six finished files from the last few days (relative dates stay stable),
/// videos and audio, written as empty files in [dir] — except one, which the
/// library's start-up check then flags as missing.
Future<void> seedLibrary(LibraryRepo library, Directory dir) async {
  const mb = 1024 * 1024;
  final now = DateTime.now();
  var n = 0;
  Future<void> add(
    String title, {
    MediaKind kind = MediaKind.video,
    int height = 1080,
    int megabytes = 245,
    int daysAgo = 0,
    int minutes = 18,
    bool missing = false,
  }) async {
    final id = 'item${n++}';
    final path = '${dir.path}/$id.${kind == MediaKind.audio ? 'mp3' : 'mp4'}';
    if (!missing) await File(path).writeAsString('');
    await library.add(
      LibraryItem(
        id: id,
        videoId: 'video$id',
        sourceUrl: 'https://www.youtube.com/watch?v=video$id',
        title: title,
        channel: 'Open Movie Studio',
        kind: kind,
        container: kind == MediaKind.audio
            ? OutContainer.mp3
            : OutContainer.mp4,
        path: path,
        bytes: megabytes * mb,
        completedAt: now.subtract(Duration(days: daysAgo)),
        height: kind == MediaKind.video ? height : null,
        duration: Duration(minutes: minutes, seconds: 42),
        missing: missing,
      ),
    );
  }

  await add('Mastering Color Grading in Practice');
  await add(
    'Building a Realtime Raytracer',
    height: 2160,
    megabytes: 410,
    daysAgo: 1,
  );
  await add(
    'Lo-Fi Beats for Deep Focus',
    kind: MediaKind.audio,
    megabytes: 145,
    daysAgo: 2,
    minutes: 74,
  );
  await add('درس البرمجة للمبتدئين', megabytes: 185, daysAgo: 3);
  await add('Short Film: Open Movie', megabytes: 96, daysAgo: 4, missing: true);
  await add(
    'Podcast Episode 12',
    kind: MediaKind.audio,
    megabytes: 60,
    daysAgo: 5,
    minutes: 52,
  );
}
