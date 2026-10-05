import 'dart:async';

import 'package:clock/clock.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/download_core/domain/entities/stream_target.dart';
import 'package:tube_downloader/core/download_core/domain/naming/file_name_template.dart';
import 'package:tube_downloader/core/download_core/domain/repos/download_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_muxer.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_transport.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/repos/thumbnail_store.dart';
import 'package:tube_downloader/core/download_core/domain/services/progress_throttler.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';

/// How a job ended. Retry / backoff decisions belong to the queue.
sealed class JobResult {
  const JobResult();
}

final class JobCompleted extends JobResult {
  const JobCompleted(this.path);
  final String path;
}

/// Paused or cancelled on request; the job already wrote that state.
final class JobStopped extends JobResult {
  const JobStopped();
}

final class JobFailed extends JobResult {
  const JobFailed(this.failure);
  final AppFailure failure;
}

/// Everything a job needs, bundled so the queue builds jobs in one line.
class JobDeps {
  const JobDeps({
    required this.repo,
    required this.library,
    required this.settings,
    required this.resolver,
    required this.transport,
    required this.muxer,
    required this.fs,
    this.thumbnails = const NoThumbnailStore(),
    this.clock = const Clock(),
    this.checkpointEvery = const Duration(seconds: 5),
  });

  final DownloadRepo repo;
  final LibraryRepo library;
  final SettingsRepo settings;
  final MediaResolver resolver;
  final MediaTransport transport;
  final MediaMuxer muxer;
  final FileSystemGateway fs;
  final ThumbnailStore thumbnails;
  final Clock clock;

  /// How often a running leg's byte count is saved (recovery reads the file
  /// length anyway; this keeps the list accurate after a restart).
  final Duration checkpointEvery;
}

/// Runs one task end to end: resolve → legs → FFmpeg → publish → library.
class DownloadJob {
  DownloadJob(this._task, this._d, {required this.onProgress});

  DownloadTask _task;
  final JobDeps _d;
  final void Function(LiveProgress) onProgress;

  _Stop? _stop;
  final _speed = SpeedMeter();
  final _throttle = ProgressThrottler();
  DateTime _lastCheckpoint = DateTime.fromMillisecondsSinceEpoch(0);

  String get taskId => _task.id;
  TaskStatus get status => _task.status;

  /// FFmpeg runs to the end; everything before it can pause.
  bool get canPause =>
      _task.status != TaskStatus.merging &&
      _task.status != TaskStatus.converting;

  Future<void> pause(PauseReason reason) async {
    if (!canPause || _stop != null) return;
    _stop = _Stop.pause(reason);
    await _d.transport.stop(taskId);
  }

  Future<void> cancel() async {
    _stop = const _Stop.cancel();
    await _d.transport.stop(taskId);
    await _d.muxer.cancel(taskId);
  }

  Future<JobResult> run() async {
    try {
      await _move(TaskStatus.resolving);
      final legs = await _planLegs();
      if (_stop != null) return await _stopped();

      final reResolved = <LegKind>{};
      for (final kind in legs) {
        if (_leg(kind).completed) continue;
        await _move(
          kind == LegKind.audio
              ? TaskStatus.downloadingAudio
              : TaskStatus.downloadingVideo,
          event: kind == LegKind.audio
              ? EventType.audioStarted
              : EventType.videoStarted,
        );
        while (true) {
          final target = _value(
            await _d.resolver.target(_task.media.videoId, _task.format, kind),
          );
          if (_stop != null) return await _stopped();
          final failure = await _transfer(kind, target, legs);
          if (failure == null) break;
          if (_stop != null) return await _stopped();
          // An expired / IP-bound URL: one fresh resolve per leg, resume at the offset.
          if (failure.type == FailureType.streamExpired &&
              reResolved.add(kind)) {
            await _move(
              TaskStatus.resolving,
              event: EventType.reResolved,
              args: {'leg': kind.name},
            );
            await _move(
              kind == LegKind.audio
                  ? TaskStatus.downloadingAudio
                  : TaskStatus.downloadingVideo,
            );
            continue;
          }
          return JobFailed(failure);
        }
        await _d.repo.addEvent(
          DownloadEvent(
            taskId: taskId,
            type: kind == LegKind.audio
                ? EventType.audioDone
                : EventType.videoDone,
            at: _d.clock.now(),
          ),
        );
      }

      final (output, ext) = await _postProcess(legs);
      if (_stop != null) return await _stopped();
      return await _publish(output, ext);
    } on _JobFailure catch (f) {
      return _stop != null ? await _stopped() : JobFailed(f.failure);
    }
  }

  // ── steps ────────────────────────────────────────────────────────────────

  /// Legs already on record (a resumed task) keep their kinds: a new plan
  /// could pick a different layout than the bytes on disk.
  Future<List<LegKind>> _planLegs() async {
    if (_task.legs.isNotEmpty) return [for (final l in _task.legs) l.kind];
    final legs = _value(
      await _d.resolver.plan(_task.media.videoId, _task.format),
    );
    final dir = await _d.fs.workDir(taskId);
    await _d.repo.replaceLegs(taskId, [
      for (final k in legs)
        TransferLeg(kind: k, tmpPath: '$dir/${k.name}.part'),
    ]);
    await _refresh();
    await _d.repo.addEvent(
      DownloadEvent(
        taskId: taskId,
        type: EventType.resolved,
        at: _d.clock.now(),
        args: {
          'legs': [for (final k in legs) k.name],
        },
      ),
    );
    return legs;
  }

  /// Downloads one leg; null on success, else the failure.
  Future<AppFailure?> _transfer(
    LegKind kind,
    StreamTarget target,
    List<LegKind> legs,
  ) async {
    var leg = _leg(kind);
    var resumeFrom = await _d.fs.fileLength(leg.tmpPath);
    // Resume only onto bytes of the SAME stream; anything else starts over.
    final sameStream =
        (leg.itag == null || leg.itag == target.itag) &&
        (leg.totalBytes == null || leg.totalBytes == target.totalBytes);
    if (!sameStream || resumeFrom > target.totalBytes) {
      await _d.fs.deleteFile(leg.tmpPath);
      resumeFrom = 0;
    }
    leg = leg.copyWith(
      itag: target.itag,
      ext: target.ext,
      totalBytes: target.totalBytes,
      doneBytes: resumeFrom,
    );
    await _d.repo.saveLeg(taskId, leg);
    await _refresh();

    final free = await _d.fs.freeBytes();
    if (free != null && free < _spaceNeeded(target, resumeFrom, legs)) {
      return const AppFailure(type: FailureType.storageFull);
    }

    final finished = Completer<AppFailure?>();
    final base = _bytesOfOtherLegs(kind);
    _speed.reset();
    final sub = _d.transport
        .start(
          TransferJob(
            jobId: taskId,
            target: target,
            filePath: leg.tmpPath,
            resumeFrom: resumeFrom,
          ),
        )
        .listen((update) async {
          switch (update) {
            case TransferProgress(:final doneBytes, :final totalBytes):
              _emitProgress(kind, base + doneBytes, base + totalBytes);
              await _checkpoint(kind, doneBytes);
            case TransferDone(:final bytes):
              await _d.repo.saveLeg(
                taskId,
                _leg(kind).copyWith(doneBytes: bytes, completed: true),
              );
              await _refresh();
              _emitProgress(kind, base + bytes, base + bytes, isFinal: true);
              if (!finished.isCompleted) finished.complete(null);
            case TransferFailed(:final failure):
              final onDisk = await _d.fs.fileLength(leg.tmpPath);
              await _d.repo.saveLeg(
                taskId,
                _leg(kind).copyWith(doneBytes: onDisk),
              );
              await _refresh();
              if (!finished.isCompleted) finished.complete(failure);
          }
        });
    try {
      return await finished.future;
    } finally {
      await sub.cancel();
    }
  }

  /// FFmpeg step (or none) → the file to publish and its extension.
  Future<(String, String)> _postProcess(List<LegKind> legs) async {
    final dir = await _d.fs.workDir(taskId);
    final duration = _task.media.duration;
    if (legs.length == 2) {
      final ext = _task.format.container.name;
      final out = '$dir/out.$ext';
      await _move(TaskStatus.merging, event: EventType.mergeStarted);
      await _mux(
        _d.muxer.merge(
          jobId: taskId,
          videoPath: _leg(LegKind.video).tmpPath,
          audioPath: _leg(LegKind.audio).tmpPath,
          outputPath: out,
          duration: duration,
        ),
      );
      return (out, ext);
    }
    final only = _leg(legs.single);
    if (_task.format.requiresTranscode) {
      final out = '$dir/out.mp3';
      await _move(TaskStatus.converting, event: EventType.convertStarted);
      await _mux(
        _d.muxer.toMp3(
          jobId: taskId,
          audioPath: only.tmpPath,
          outputPath: out,
          kbps: _task.format.audioKbps ?? 192,
          duration: duration,
        ),
      );
      return (out, 'mp3');
    }
    return (
      only.tmpPath,
      only.ext ?? 'mp4',
    ); // muxed video or M4A audio, as downloaded
  }

  Future<void> _mux(Stream<MuxUpdate> updates) async {
    await for (final update in updates) {
      switch (update) {
        case MuxProgress(:final fraction):
          onProgress(
            LiveProgress(
              taskId: taskId,
              doneBytes: _task.doneBytes,
              totalBytes: _task.totalBytes,
              muxFraction: fraction,
            ),
          );
        case MuxDone():
          return;
        case MuxFailed(:final failure):
          throw _JobFailure(failure);
      }
    }
  }

  Future<JobResult> _publish(String output, String ext) async {
    final settings = _d.settings.current;
    final media = _task.media;
    final base = FileNameTemplate.render(
      settings.nameTemplate,
      title: media.title,
      channel: media.channel,
      videoId: media.videoId,
      quality: _task.format.maxHeight == null
          ? null
          : '${_task.format.maxHeight}p',
      index: _task.playlistIndex,
    );
    final groupId = _task.groupId;
    final group = groupId == null ? null : await _d.repo.group(groupId);
    final path = _value(
      await _d.fs.publish(
        sourcePath: output,
        fileName: '$base.$ext',
        subDir: settings.playlistSubfolders ? group?.subDir : null,
      ),
    );
    final now = _d.clock.now();
    final thumbUrl = media.thumbnailUrl;
    final thumbPath = thumbUrl == null
        ? null
        : await _d.thumbnails.save(media.videoId, thumbUrl);
    await _d.library.add(
      LibraryItem(
        id: taskId,
        taskId: taskId,
        videoId: media.videoId,
        sourceUrl: media.url,
        title: media.title,
        channel: media.channel,
        kind: _task.format.kind,
        container: OutContainer.values.firstWhere(
          (c) => c.name == ext,
          orElse: () => OutContainer.mp4,
        ),
        height: _task.format.kind == MediaKind.video
            ? _task.format.maxHeight
            : null,
        duration: media.duration,
        path: path,
        bytes: await _d.fs.fileLength(path),
        completedAt: now,
        thumbPath: thumbPath,
      ),
    );
    _value(
      await _d.repo.transition(
        taskId,
        TaskStatus.completed,
        outputPath: path,
        event: EventType.completed,
      ),
    );
    await _d.fs.deleteWorkDir(taskId);
    return JobCompleted(path);
  }

  /// Writes the requested stop (pause keeps the bytes, cancel removes them).
  Future<JobResult> _stopped() async {
    final stop = _stop!;
    if (stop.isCancel) {
      await _d.repo.transition(
        taskId,
        TaskStatus.cancelled,
        event: EventType.cancelled,
      );
      await _d.fs.deleteWorkDir(taskId);
    } else {
      await _d.repo.transition(
        taskId,
        TaskStatus.paused,
        pauseReason: stop.reason,
        event: EventType.paused,
        eventArgs: {'reason': stop.reason!.name},
      );
    }
    return const JobStopped();
  }

  // ── helpers ──────────────────────────────────────────────────────────────

  Future<void> _move(
    TaskStatus to, {
    EventType? event,
    Map<String, Object?> args = const {},
  }) async {
    _task = _value(
      await _d.repo.transition(taskId, to, event: event, eventArgs: args),
    );
  }

  Future<void> _refresh() async =>
      _task = (await _d.repo.task(taskId)) ?? _task;

  TransferLeg _leg(LegKind kind) =>
      _task.legs.firstWhere((l) => l.kind == kind);

  int _bytesOfOtherLegs(LegKind current) => _task.legs
      .where((l) => l.kind != current && l.completed)
      .fold(0, (sum, l) => sum + (l.totalBytes ?? l.doneBytes));

  /// Remaining bytes of this leg, plus room for the merged / converted copy.
  int _spaceNeeded(StreamTarget target, int resumeFrom, List<LegKind> legs) {
    final remaining = target.totalBytes - resumeFrom;
    final output = legs.length > 1 || _task.format.requiresTranscode
        ? _task.legs.fold<int>(0, (sum, l) => sum + (l.totalBytes ?? 0)) +
              target.totalBytes
        : 0;
    return ((remaining + output) * 1.1).round();
  }

  void _emitProgress(LegKind leg, int done, int total, {bool isFinal = false}) {
    final now = _d.clock.now();
    _speed.sample(done, now);
    if (!_throttle.shouldEmit(
      done: done,
      total: total,
      now: now,
      isFinal: isFinal,
    )) {
      return;
    }
    onProgress(
      LiveProgress(
        taskId: taskId,
        leg: leg,
        doneBytes: done,
        totalBytes: total,
        bytesPerSecond: _speed.bytesPerSecond,
        eta: _speed.eta(done, total),
      ),
    );
  }

  Future<void> _checkpoint(LegKind kind, int doneBytes) async {
    final now = _d.clock.now();
    if (now.difference(_lastCheckpoint) < _d.checkpointEvery) return;
    _lastCheckpoint = now;
    await _d.repo.saveLeg(taskId, _leg(kind).copyWith(doneBytes: doneBytes));
  }

  static T _value<T>(Result<T> result) => switch (result) {
    Success(:final data) => data,
    Failure(:final failure) => throw _JobFailure(failure),
  };
}

final class _JobFailure implements Exception {
  const _JobFailure(this.failure);
  final AppFailure failure;
}

final class _Stop {
  const _Stop.pause(PauseReason this.reason) : isCancel = false;
  const _Stop.cancel() : reason = null, isCancel = true;
  final PauseReason? reason;
  final bool isCancel;
}
