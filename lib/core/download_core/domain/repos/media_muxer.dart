import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/error/app_failure.dart';

part 'media_muxer.freezed.dart';

/// FFmpeg behind a contract: merge separate video + audio without
/// re-encoding, or convert audio to MP3. Streams end with `done` or `failed`.
abstract interface class MediaMuxer {
  Stream<MuxUpdate> merge({
    required String jobId,
    required String videoPath,
    required String audioPath,
    required String outputPath,
    Duration? duration,
  });

  Stream<MuxUpdate> toMp3({
    required String jobId,
    required String audioPath,
    required String outputPath,
    required int kbps,
    Duration? duration,
  });

  Future<void> cancel(String jobId);
}

@freezed
sealed class MuxUpdate with _$MuxUpdate {
  /// 0–1, from FFmpeg's `time=` against the known duration.
  const factory MuxUpdate.progress(double fraction) = MuxProgress;
  const factory MuxUpdate.done() = MuxDone;
  const factory MuxUpdate.failed(AppFailure failure) = MuxFailed;
}
