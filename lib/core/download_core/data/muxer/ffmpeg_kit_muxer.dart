import 'dart:async';

import 'package:ffmpeg_kit_flutter_new_audio/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_audio/return_code.dart';
import 'package:tube_downloader/core/download_core/data/muxer/ffmpeg_commands.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_muxer.dart';
import 'package:tube_downloader/core/error/app_exceptions.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';

/// [MediaMuxer] on `ffmpeg_kit_flutter_new_audio` (Android, iOS, macOS,
/// Windows x64). Each run is an async FFmpegKit session, cancellable by id.
class FfmpegKitMuxer implements MediaMuxer {
  final _sessions = <String, int>{};

  @override
  Stream<MuxUpdate> merge({
    required String jobId,
    required String videoPath,
    required String audioPath,
    required String outputPath,
    Duration? duration,
  }) => _run(
    jobId,
    FfmpegCommands.merge(
      videoPath: videoPath,
      audioPath: audioPath,
      outputPath: outputPath,
    ),
    duration,
  );

  @override
  Stream<MuxUpdate> toMp3({
    required String jobId,
    required String audioPath,
    required String outputPath,
    required int kbps,
    Duration? duration,
  }) => _run(
    jobId,
    FfmpegCommands.toMp3(
      audioPath: audioPath,
      outputPath: outputPath,
      kbps: kbps,
    ),
    duration,
  );

  @override
  Future<void> cancel(String jobId) async {
    final session = _sessions.remove(jobId);
    if (session != null) await FFmpegKit.cancel(session);
  }

  Stream<MuxUpdate> _run(String jobId, List<String> args, Duration? duration) {
    final controller = StreamController<MuxUpdate>();
    unawaited(
      FFmpegKit.executeWithArgumentsAsync(
        args,
        (session) async {
          _sessions.remove(jobId);
          final rc = await session.getReturnCode();
          if (ReturnCode.isSuccess(rc)) {
            controller.add(const MuxUpdate.done());
          } else if (ReturnCode.isCancel(rc)) {
            controller.add(
              MuxUpdate.failed(FailureMapper.map(const CancelledException())),
            );
          } else {
            final logs = await session.getAllLogsAsString() ?? '';
            final tail = logs
                .trimRight()
                .split('\n')
                .reversed
                .take(6)
                .toList()
                .reversed
                .join('\n');
            controller.add(
              MuxUpdate.failed(
                FailureMapper.map(
                  FfmpegException(rc?.getValue(), logTail: tail),
                ),
              ),
            );
          }
          await controller.close();
        },
        null,
        (statistics) {
          final fraction = FfmpegCommands.progressFraction(
            statistics.getTime(),
            duration,
          );
          if (fraction != null && !controller.isClosed) {
            controller.add(MuxUpdate.progress(fraction));
          }
        },
      ).then((session) {
        final id = session.getSessionId();
        if (id != null && !controller.isClosed) _sessions[jobId] = id;
      }),
    );
    return controller.stream;
  }
}
