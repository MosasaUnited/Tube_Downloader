import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/features/new_download/domain/size_estimator.dart';

part 'batch_links_state.freezed.dart';

enum BatchItemStatus {
  /// Waiting for, or in, its metadata fetch.
  resolving,
  ready,

  /// Not a YouTube video or playlist link.
  invalid,

  /// The same video (or playlist) appears earlier in the box.
  duplicate,

  /// A playlist link: downloaded from the Playlist tab, not here.
  playlist,

  /// The fetch failed (private, unavailable, live, offline…).
  failed,
}

/// One row of the "Resolved items" list.
@freezed
abstract class BatchItem with _$BatchItem {
  const factory BatchItem({
    required int position,
    required String input,
    required BatchItemStatus status,
    String? videoId,
    MediaInfo? media,
    AppFailure? failure,
    int? duplicateOf,
  }) = _BatchItem;

  const BatchItem._();

  /// Offline and rate-limit failures can succeed later; private or deleted
  /// videos can't.
  bool get canRetry => switch (failure?.type) {
    FailureType.noInternet ||
    FailureType.serverUnreachable ||
    FailureType.rateLimited ||
    FailureType.unknown => true,
    _ => false,
  };
}

@freezed
abstract class BatchLinksState with _$BatchLinksState {
  const factory BatchLinksState({
    /// The box's text — the source of truth for the rows.
    @Default('') String text,
    @Default(<BatchItem>[]) List<BatchItem> items,

    /// The quality for every row without its own.
    required FormatSelector format,

    /// Per-video quality, by video id.
    @Default(<String, FormatSelector>{}) Map<String, FormatSelector> overrides,
    String? saveDirectory,
    @Default(false) bool enqueuing,
  }) = _BatchLinksState;
}

extension BatchLinksStateX on BatchLinksState {
  MediaKind get kind => format.kind;

  Iterable<BatchItem> get readyItems =>
      items.where((i) => i.status == BatchItemStatus.ready);

  int count(BatchItemStatus status) =>
      items.where((i) => i.status == status).length;

  FormatSelector formatOf(BatchItem item) => overrides[item.videoId] ?? format;

  int? estimateOf(BatchItem item) =>
      SizeEstimator.estimate(item.media?.duration, formatOf(item));

  /// Sum of the ready rows' estimates (rows without a duration count 0).
  int get readyBytes =>
      readyItems.fold(0, (sum, i) => sum + (estimateOf(i) ?? 0));
}
