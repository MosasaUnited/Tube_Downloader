import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/error/app_failure.dart';

part 'result.freezed.dart';

/// Outcome of any operation that can fail. Contracts return it instead of
/// throwing, so every caller handles both branches.
@freezed
sealed class Result<T> with _$Result<T> {
  const factory Result.success(T data) = Success<T>;
  const factory Result.failure(AppFailure failure) = Failure<T>;
}
