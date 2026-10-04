import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/naming/file_name_sanitizer.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/features/new_download/domain/default_format_picker.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';
import 'package:tube_downloader/features/new_download/logic/playlist_cubit/playlist_state.dart';
import 'package:uuid/uuid.dart';

/// A playlist: header, streamed items, selection, one quality for all (with
/// per-row overrides), and one enqueue as a download group.
class PlaylistCubit extends Cubit<PlaylistState> {
  PlaylistCubit(
    this._resolver,
    this._enqueue,
    this._settings, {
    String Function()? newId,
  }) : _newId = newId ?? const Uuid().v4,
       super(const PlaylistState.idle());

  final MediaResolver _resolver;
  final EnqueueDownloadsUseCase _enqueue;
  final SettingsRepo _settings;
  final String Function() _newId;

  StreamSubscription<Result<MediaInfo>>? _items;
  Timer? _flush;
  final _pending = <PlaylistRow>[];

  /// Titles YouTube gives entries that can't be played.
  static const _unavailableTitles = {'[private video]', '[deleted video]'};

  Future<void> fetch(ParsedLink link) async {
    await _stopItems();
    emit(const PlaylistState.loading());
    final resolved = await _resolver.resolve(link);
    if (isClosed) return;
    switch (resolved) {
      case Failure(:final failure):
        return emit(PlaylistState.failure(failure));
      case Success(:final data) when data is ResolvedPlaylist:
        final settings = _settings.current;
        emit(
          PlaylistState.ready(
            playlist: data.playlist,
            rows: const [],
            format: DefaultFormatPicker.selectorFor(
              settings.defaultKind,
              settings,
            ),
            subfolder: settings.playlistSubfolders,
          ),
        );
        _streamItems(data.playlist.playlistId);
      case Success():
        emit(
          const PlaylistState.failure(
            AppFailure(type: FailureType.unsupportedLink),
          ),
        );
    }
  }

  /// Items arrive one by one; the UI is updated in batches (every 150 ms) so
  /// a long playlist doesn't rebuild the list hundreds of times.
  void _streamItems(String playlistId) {
    var index = 0;
    _items = _resolver
        .playlistItems(playlistId)
        .listen(
          (result) {
            switch (result) {
              case Success(:final data):
                final unavailable = _unavailableTitles.contains(
                  data.title.trim().toLowerCase(),
                );
                _pending.add(
                  PlaylistRow(
                    index: ++index,
                    media: data,
                    unavailable: unavailable,
                    selected: !unavailable,
                  ),
                );
                _flush ??= Timer(
                  const Duration(milliseconds: 150),
                  _flushPending,
                );
              case Failure(:final failure):
                _flushPending();
                _update((s) => s.copyWith(itemsFailure: failure));
            }
          },
          onDone: () {
            _flushPending();
            _update((s) => s.copyWith(loadingMore: false));
          },
        );
  }

  void _flushPending() {
    _flush?.cancel();
    _flush = null;
    if (_pending.isEmpty) return;
    final added = List<PlaylistRow>.of(_pending);
    _pending.clear();
    _update((s) => s.copyWith(rows: [...s.rows, ...added]));
  }

  void _update(PlaylistReady Function(PlaylistReady) change) {
    final s = state;
    if (!isClosed && s is PlaylistReady) emit(change(s));
  }

  void toggle(int index) => _update(
    (s) => s.copyWith(
      rows: [
        for (final r in s.rows)
          r.index == index && !r.unavailable
              ? r.copyWith(selected: !r.selected)
              : r,
      ],
    ),
  );

  void selectAll(bool selected) => _update(
    (s) => s.copyWith(
      rows: [
        for (final r in s.rows)
          r.unavailable ? r : r.copyWith(selected: selected),
      ],
    ),
  );

  /// Video ↔ audio for the whole playlist (per-row overrides of the other
  /// kind no longer make sense and are dropped).
  void setKind(MediaKind kind) => _update((s) {
    if (s.format.kind == kind) return s;
    return s.copyWith(
      format: DefaultFormatPicker.selectorFor(kind, _settings.current),
      rows: [for (final r in s.rows) r.copyWith(formatOverride: null)],
    );
  });

  void setFormat(FormatSelector format) =>
      _update((s) => s.copyWith(format: format));

  void setOverride(int index, FormatSelector? format) => _update(
    (s) => s.copyWith(
      rows: [
        for (final r in s.rows)
          r.index == index ? r.copyWith(formatOverride: format) : r,
      ],
    ),
  );

  void setFilter(String filter) => _update((s) => s.copyWith(filter: filter));

  void setSubfolder(bool value) => _update((s) => s.copyWith(subfolder: value));

  Future<Result<EnqueueSummary>?> download() async {
    final s = state;
    if (s is! PlaylistReady || s.enqueuing || s.selectedCount == 0) return null;
    emit(s.copyWith(enqueuing: true));
    final requests = [
      for (final row in s.downloadable)
        DownloadRequest(
          media: row.media,
          format: s.formatOf(row),
          playlistIndex: row.index,
        ),
    ];
    final group = DownloadGroup(
      id: _newId(),
      playlistId: s.playlist.playlistId,
      title: s.playlist.title,
      channel: s.playlist.channel,
      total: requests.length,
      subDir: s.subfolder
          ? FileNameSanitizer.sanitize(
              s.playlist.title,
              fallback: s.playlist.playlistId,
            )
          : null,
    );
    final result = await _enqueue(requests, group: group);
    _update((now) => now.copyWith(enqueuing: false));
    return result;
  }

  Future<void> _stopItems() async {
    _flush?.cancel();
    _flush = null;
    _pending.clear();
    await _items?.cancel();
    _items = null;
  }

  @override
  Future<void> close() async {
    await _stopItems();
    return super.close();
  }
}
