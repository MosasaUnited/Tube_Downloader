import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/error/failure_type.dart';

part 'app_failure.freezed.dart';

/// The one failure value that travels every layer (download-errors skill).
///
/// [debug] carries the technical detail for logs only — it is never rendered.
/// Build one through `FailureMapper.map(e, s)`, not by hand from `e.toString()`.
@freezed
abstract class AppFailure with _$AppFailure {
  const factory AppFailure({
    required FailureType type,
    String? debug,
    Duration? retryAfter,
  }) = _AppFailure;

  const AppFailure._();

  bool get isSilent => type.isSilent;
}
