import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';

const _video = FormatSelector(
  kind: MediaKind.video,
  container: OutContainer.mp4,
  maxHeight: 1080,
);
const _mp3 = FormatSelector(
  kind: MediaKind.audio,
  container: OutContainer.mp3,
  audioKbps: 320,
);

DownloadRequest _request(
  String id,
  String title, {
  FormatSelector format = _video,
  int? index,
}) => DownloadRequest(
  media: MediaInfo(
    videoId: id,
    url: 'https://www.youtube.com/watch?v=$id',
    title: title,
    channel: 'Open Movie Studio',
    duration: const Duration(minutes: 24, seconds: 18),
  ),
  format: format,
  playlistIndex: index,
);

/// A queue with one download in every state the Downloads tab draws, and a
/// two-video playlist. Returns the task ids by state name.
Future<Map<String, String>> seedEveryState(DownloadRepo repo) async {
  Future<String> add(DownloadRequest r, {DownloadGroup? group}) async =>
      (await repo.enqueue([
        r,
      ], group: group) as Success<List<String>>).data.single;
  Future<void> walk(String id, List<TaskStatus> path) async {
    for (final to in path) {
      await repo.transition(id, to);
    }
  }

  Future<void> leg(String id, LegKind kind, int done, int total) =>
      repo.saveLeg(
        id,
        TransferLeg(
          kind: kind,
          tmpPath: '/work/$id/${kind.name}.part',
          doneBytes: done,
          totalBytes: total,
          ext: kind == LegKind.audio ? 'm4a' : 'mp4',
          completed: done == total,
        ),
      );

  const mb = 1024 * 1024;
  final ids = <String, String>{};

  final downloading = await add(
    _request('downloading', 'A Midnight Walk Through the Neon City'),
  );
  await walk(downloading, [TaskStatus.resolving, TaskStatus.downloadingVideo]);
  await leg(downloading, LegKind.video, 640 * mb, 940 * mb);
  await leg(downloading, LegKind.audio, 0, 38 * mb);
  ids['downloading'] = downloading;

  final merging = await add(
    _request('merging', 'Deep Oceans: The Hidden World Below'),
  );
  await walk(merging, [
    TaskStatus.resolving,
    TaskStatus.downloadingVideo,
    TaskStatus.downloadingAudio,
    TaskStatus.merging,
  ]);
  await leg(merging, LegKind.video, 1400 * mb, 1400 * mb);
  await leg(merging, LegKind.audio, 60 * mb, 60 * mb);
  ids['merging'] = merging;

  final paused = await add(
    _request('paused', 'Chill Study Beats, Vol. 3', format: _mp3),
  );
  await walk(paused, [TaskStatus.resolving, TaskStatus.downloadingAudio]);
  await leg(paused, LegKind.audio, 145 * mb, 340 * mb);
  await repo.transition(
    paused,
    TaskStatus.paused,
    pauseReason: PauseReason.waitingForWifi,
  );
  ids['paused'] = paused;

  final failed = await add(
    _request('failedtask', 'Conference Keynote: Building Secure Systems'),
  );
  await walk(failed, [TaskStatus.resolving, TaskStatus.downloadingVideo]);
  await repo.transition(
    failed,
    TaskStatus.failed,
    failure: const AppFailure(type: FailureType.serverUnreachable),
  );
  ids['failed'] = failed;

  final queued = await add(_request('queuedtask', 'Building a Raytracer'));
  ids['queued'] = queued;

  final done = await add(_request('completed', 'Short Film: Tears of Steel'));
  await walk(done, [
    TaskStatus.resolving,
    TaskStatus.downloadingVideo,
    TaskStatus.downloadingAudio,
    TaskStatus.merging,
  ]);
  await leg(done, LegKind.video, 245 * mb, 245 * mb);
  await leg(done, LegKind.audio, 11 * mb, 11 * mb);
  await repo.transition(
    done,
    TaskStatus.completed,
    outputPath: '/Users/me/Movies/Tube Downloader/Short Film - Studio.mp4',
  );
  ids['completed'] = done;

  const group = DownloadGroup(
    id: 'mix',
    playlistId: 'PLabcdefghij12',
    title: 'Lo-fi Coding Mix 2026',
    total: 2,
  );
  // One enqueue for the playlist, as the Playlist tab does.
  final playlist = (await repo.enqueue([
    _request('playlist001', 'Night Train (Rain Audio)', index: 13),
    _request('playlist002', 'Neon Coffee Shop Ambience', index: 14),
  ], group: group) as Success<List<String>>).data;
  final first = playlist[0];
  final second = playlist[1];
  await walk(first, [TaskStatus.resolving, TaskStatus.downloadingAudio]);
  await leg(first, LegKind.audio, 92 * mb, 100 * mb);
  ids['group'] = 'mix';
  ids['groupFirst'] = first;
  ids['groupSecond'] = second;
  return ids;
}
