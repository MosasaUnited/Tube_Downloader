import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_task.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/entities/parsed_link.dart';
import 'package:tube_downloader/core/download_core/domain/repos/media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/link_file_reader.dart';
import 'package:tube_downloader/features/new_download/domain/default_format_picker.dart';
import 'package:tube_downloader/features/new_download/domain/link_batch_analyzer.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';
import 'package:tube_downloader/features/new_download/logic/batch_links_cubit/batch_links_state.dart';

/// The Multiple-links tab: the text box is the source of truth; every change
/// re-analyzes it (offline) and fetches metadata for new videos one at a time.
class BatchLinksCubit extends Cubit<BatchLinksState> {
  BatchLinksCubit(
    this._resolver,
    this._enqueue,
    this._settings,
    this._clipboard,
    this._files,
  ) : super(
        BatchLinksState(
          format: DefaultFormatPicker.selectorFor(
            _settings.current.defaultKind,
            _settings.current,
          ),
          saveDirectory: _settings.current.saveDirectory,
        ),
      );

  final MediaResolver _resolver;
  final EnqueueDownloadsUseCase _enqueue;
  final SettingsRepo _settings;
  final ClipboardService _clipboard;
  final LinkFileReader _files;

  /// Typing re-analyzes after a short pause, not on every key.
  static const analyzeDelay = Duration(milliseconds: 400);

  Timer? _analyzeTimer;
  List<BatchEntry> _entries = const [];

  /// Fetch results by video id. Kept when a line is edited away and back, so
  /// the same video is never fetched twice.
  final _resolved = <String, Result<MediaInfo>>{};
  bool _resolving = false;

  void setText(String text) {
    if (text == state.text) return;
    emit(state.copyWith(text: text));
    _analyzeTimer?.cancel();
    _analyzeTimer = Timer(analyzeDelay, _analyze);
  }

  /// Paste, import and drop: added on a new line and analyzed at once.
  void append(String links) {
    final added = links.trim();
    if (added.isEmpty) return;
    final current = state.text.trimRight();
    emit(state.copyWith(text: current.isEmpty ? added : '$current\n$added'));
    _analyze();
  }

  Future<void> paste() async {
    final text = await _clipboard.readText();
    if (isClosed || text == null) return;
    append(text);
  }

  /// Returns the failure for the screen to report; null when it worked or
  /// the user cancelled.
  Future<AppFailure?> importFile() async {
    final result = await _files.pickText();
    if (isClosed) return null;
    switch (result) {
      case Failure(:final failure):
        return failure;
      case Success(:final data):
        if (data != null) append(data);
        return null;
    }
  }

  void clear() {
    _analyzeTimer?.cancel();
    _entries = const [];
    emit(state.copyWith(text: '', items: const []));
  }

  /// Removes the row's link from the box (the box stays the source of truth).
  void remove(int position) {
    _analyzeNow();
    final entry = _entries.where((e) => e.position == position).firstOrNull;
    if (entry == null) return;
    emit(state.copyWith(text: LinkBatchAnalyzer.remove(state.text, [entry])));
    _analyze();
  }

  void retry(String videoId) {
    _resolved.remove(videoId);
    _refresh();
    unawaited(_resolveNext());
  }

  /// Video ↔ audio for every row (overrides of the other kind are dropped).
  void setKind(MediaKind kind) {
    if (state.kind == kind) return;
    emit(
      state.copyWith(
        format: DefaultFormatPicker.selectorFor(kind, _settings.current),
        overrides: const {},
      ),
    );
  }

  void setFormat(FormatSelector format) => emit(state.copyWith(format: format));

  void setOverride(String videoId, FormatSelector? format) {
    final overrides = {...state.overrides};
    if (format == null) {
      overrides.remove(videoId);
    } else {
      overrides[videoId] = format;
    }
    emit(state.copyWith(overrides: overrides));
  }

  /// Queues every ready row, then takes the queued links out of the box —
  /// what stays (invalid, failed, still resolving) is what needs attention.
  Future<Result<EnqueueSummary>?> download() async {
    _analyzeNow();
    final s = state;
    final ready = s.readyItems.toList();
    if (s.enqueuing || ready.isEmpty) return null;
    emit(s.copyWith(enqueuing: true));
    final result = await _enqueue([
      for (final item in ready)
        DownloadRequest(media: item.media!, format: s.formatOf(item)),
    ]);
    if (isClosed) return result;
    emit(state.copyWith(enqueuing: false));
    if (result is Success) {
      // The text may have changed while queueing: match by video, not offset.
      _analyzeNow();
      final queued = {for (final item in ready) item.videoId};
      final text = LinkBatchAnalyzer.remove(
        state.text,
        _entries.where((e) => queued.contains(e.videoId)),
      );
      emit(state.copyWith(text: text));
      _analyze();
    }
    return result;
  }

  void _analyzeNow() {
    if (_analyzeTimer?.isActive ?? false) _analyze();
  }

  void _analyze() {
    _analyzeTimer?.cancel();
    if (isClosed) return;
    _entries = LinkBatchAnalyzer.analyze(state.text);
    _refresh();
    unawaited(_resolveNext());
  }

  void _refresh() {
    if (isClosed) return;
    emit(state.copyWith(items: [for (final e in _entries) _itemOf(e)]));
  }

  BatchItem _itemOf(BatchEntry entry) {
    final id = entry.videoId;
    final resolved = id == null ? null : _resolved[id];
    final status = switch (entry.link) {
      _ when entry.duplicateOf != null => BatchItemStatus.duplicate,
      ParsedUnsupported() => BatchItemStatus.invalid,
      ParsedPlaylist() => BatchItemStatus.playlist,
      ParsedVideo() => switch (resolved) {
        null => BatchItemStatus.resolving,
        Success() => BatchItemStatus.ready,
        Failure() => BatchItemStatus.failed,
      },
    };
    return BatchItem(
      position: entry.position,
      input: entry.input,
      status: status,
      videoId: id,
      media: resolved is Success<MediaInfo> ? resolved.data : null,
      failure: resolved is Failure<MediaInfo> ? resolved.failure : null,
      duplicateOf: entry.duplicateOf,
    );
  }

  /// One fetch at a time, first row first. The resolver's gate spaces calls
  /// anyway; fetching serially here means clearing the box stops the work
  /// instead of leaving dozens of calls waiting in that gate.
  Future<void> _resolveNext() async {
    if (_resolving) return;
    _resolving = true;
    try {
      while (!isClosed) {
        final next = _entries
            .where(
              (e) =>
                  e.duplicateOf == null &&
                  e.videoId != null &&
                  !_resolved.containsKey(e.videoId),
            )
            .firstOrNull;
        if (next == null) return;
        final result = await _resolver.resolve(next.link);
        if (isClosed) return;
        _resolved[next.videoId!] = _mediaOf(result);
        _refresh();
      }
    } finally {
      _resolving = false;
    }
  }

  static Result<MediaInfo> _mediaOf(Result<ResolvedLink> result) =>
      switch (result) {
        Failure(:final failure) => Result.failure(failure),
        Success(data: ResolvedSingle(:final media)) when media.isLive =>
          const Result.failure(AppFailure(type: FailureType.liveNotSupported)),
        Success(data: ResolvedSingle(:final media)) => Result.success(media),
        Success() => const Result.failure(
          AppFailure(type: FailureType.unsupportedLink),
        ),
      };

  @override
  Future<void> close() {
    _analyzeTimer?.cancel();
    return super.close();
  }
}
