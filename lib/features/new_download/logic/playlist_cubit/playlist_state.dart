import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/features/new_download/domain/size_estimator.dart';

part 'playlist_state.freezed.dart';

/// One video of the playlist.
@freezed
abstract class PlaylistRow with _$PlaylistRow {
  const factory PlaylistRow({
    /// 1-based position in the playlist.
    required int index,
    required MediaInfo media,
    @Default(true) bool selected,

    /// This row's own quality; null = the playlist-wide one.
    FormatSelector? formatOverride,

    /// Private / deleted entries: shown disabled, never downloaded.
    @Default(false) bool unavailable,
  }) = _PlaylistRow;
}

@freezed
sealed class PlaylistState with _$PlaylistState {
  const factory PlaylistState.idle() = PlaylistIdle;
  const factory PlaylistState.loading() = PlaylistLoading;
  const factory PlaylistState.ready({
    required PlaylistInfo playlist,
    required List<PlaylistRow> rows,
    required FormatSelector format,
    @Default(true) bool loadingMore,
    @Default('') String filter,
    @Default(true) bool subfolder,
    @Default(false) bool enqueuing,

    /// The item stream stopped early; the rows loaded so far stay usable.
    AppFailure? itemsFailure,
  }) = PlaylistReady;
  const factory PlaylistState.failure(AppFailure failure) = PlaylistFailure;
}

extension PlaylistReadyX on PlaylistReady {
  MediaKind get kind => format.kind;

  Iterable<PlaylistRow> get downloadable =>
      rows.where((r) => r.selected && !r.unavailable);

  int get selectedCount => downloadable.length;

  int get availableCount => rows.where((r) => !r.unavailable).length;

  List<PlaylistRow> get visibleRows {
    final query = filter.trim().toLowerCase();
    return query.isEmpty
        ? rows
        : rows
              .where((r) => r.media.title.toLowerCase().contains(query))
              .toList();
  }

  FormatSelector formatOf(PlaylistRow row) => row.formatOverride ?? format;

  int? estimateOf(PlaylistRow row) =>
      SizeEstimator.estimate(row.media.duration, formatOf(row));

  /// Sum of the selected rows' estimates (rows without a duration count 0).
  int get selectedBytes =>
      downloadable.fold(0, (sum, r) => sum + (estimateOf(r) ?? 0));

  Duration get totalDuration => rows.fold(
    Duration.zero,
    (sum, r) => sum + (r.media.duration ?? Duration.zero),
  );
}
