import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_option.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/error/app_failure.dart';

part 'single_link_state.freezed.dart';

@freezed
sealed class SingleLinkState with _$SingleLinkState {
  const factory SingleLinkState.idle() = SingleIdle;
  const factory SingleLinkState.loading() = SingleLoading;
  const factory SingleLinkState.ready({
    required MediaInfo media,
    required List<FormatOption> options,
    required MediaKind kind,
    required FormatOption selected,

    /// The Settings-default pick for [kind] (shown as "Recommended").
    required FormatOption recommended,

    /// Where the file will be saved; null = the platform default folder.
    String? saveDirectory,
    @Default(false) bool enqueuing,
  }) = SingleReady;
  const factory SingleLinkState.failure(AppFailure failure) = SingleFailure;
}
