import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/stream_target.dart';
import 'package:tube_downloader/core/error/app_failure.dart';

part 'media_transport.freezed.dart';

/// Moves the bytes of one leg into a file.
abstract interface class MediaTransport {
  /// Downloads [job]. The file already holds bytes `0 … resumeFrom-1`.
  /// Emits progress, then exactly one `done` or `failed`; never throws.
  Stream<TransferUpdate> start(TransferJob job);

  /// Stops [jobId] and keeps what is on disk (pause = stop; resume = start
  /// again from the file length).
  Future<void> stop(String jobId);
}

@freezed
abstract class TransferJob with _$TransferJob {
  const factory TransferJob({
    required String jobId,
    required StreamTarget target,
    required String filePath,
    @Default(0) int resumeFrom,
  }) = _TransferJob;
}

@freezed
sealed class TransferUpdate with _$TransferUpdate {
  const factory TransferUpdate.progress({
    required int doneBytes,
    required int totalBytes,
  }) = TransferProgress;
  const factory TransferUpdate.done(int bytes) = TransferDone;
  const factory TransferUpdate.failed(AppFailure failure) = TransferFailed;
}
