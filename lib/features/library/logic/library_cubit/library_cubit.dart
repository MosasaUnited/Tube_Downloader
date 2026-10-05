import 'dart:async';
import 'dart:ui';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/clipboard_service.dart';
import 'package:tube_downloader/core/platform/file_launcher.dart';
import 'package:tube_downloader/features/library/domain/usecases/check_missing_files_use_case.dart';
import 'package:tube_downloader/features/library/domain/usecases/delete_library_items_use_case.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_state.dart';

/// The Library tab: search (Arabic-normalised by the repo), Video/Audio,
/// sort, grid/list, multi-select, and what can be done with the files.
class LibraryCubit extends Cubit<LibraryState> {
  LibraryCubit(
    this._library,
    this._files,
    this._clipboard,
    this._checkMissing,
    this._delete,
  ) : super(const LibraryState());

  final LibraryRepo _library;
  final FileLauncher _files;
  final ClipboardService _clipboard;
  final CheckMissingFilesUseCase _checkMissing;
  final DeleteLibraryItemsUseCase _delete;

  /// Typing searches after a short pause, not on every key.
  static const searchDelay = Duration(milliseconds: 250);

  StreamSubscription<List<LibraryItem>>? _sub;
  Timer? _searchTimer;

  bool get canReveal => _files.canReveal;
  bool get canSaveToPhotos => _files.canSaveToPhotos;

  /// Starts listening and flags files moved or deleted outside the app.
  void start() {
    _watch();
    unawaited(_checkMissing());
  }

  void setQuery(String query) {
    if (query == state.query) return;
    emit(state.copyWith(query: query));
    _searchTimer?.cancel();
    _searchTimer = Timer(searchDelay, _watch);
  }

  void setKind(MediaKind? kind) =>
      emit(state.copyWith(kind: kind, selected: const {}));

  void setSort(LibrarySort sort) {
    if (sort == state.sort) return;
    emit(state.copyWith(sort: sort));
    _watch();
  }

  void setView(LibraryView view) => emit(state.copyWith(view: view));

  void setSelecting(bool selecting) =>
      emit(state.copyWith(selecting: selecting, selected: const {}));

  void toggle(String id) {
    final selected = {...state.selected};
    if (!selected.remove(id)) selected.add(id);
    emit(state.copyWith(selecting: true, selected: selected));
  }

  void selectAll() =>
      emit(state.copyWith(selected: {for (final i in state.visible) i.id}));

  Future<AppFailure?> open(LibraryItem item) => _files.open(item.path);
  Future<AppFailure?> reveal(LibraryItem item) => _files.reveal(item.path);
  Future<void> copyLink(LibraryItem item) =>
      _clipboard.writeText(item.sourceUrl);

  Future<AppFailure?> share(List<LibraryItem> items, {Rect? origin}) =>
      _files.share([for (final i in items) i.path], origin: origin);

  /// Videos of [items] to Photos; returns how many went, or the failure.
  Future<Result<int>> saveToPhotos(List<LibraryItem> items) async {
    final videos = [
      for (final i in items)
        if (i.kind == MediaKind.video && !i.missing) i.path,
    ];
    final failure = await _files.saveToPhotos(videos);
    return failure == null
        ? Result.success(videos.length)
        : Result.failure(failure);
  }

  Future<Result<void>> delete(
    List<LibraryItem> items, {
    required bool fromDisk,
  }) async {
    final result = await _delete(items, fromDisk: fromDisk);
    if (!isClosed && result is Success<void>) setSelecting(false);
    return result;
  }

  void _watch() {
    _searchTimer?.cancel();
    final previous = _sub;
    _sub = _library.watch(query: state.query, sort: state.sort).listen((items) {
      if (isClosed) return;
      final ids = {for (final i in items) i.id};
      emit(
        state.copyWith(
          matches: items,
          loaded: true,
          // Deleted elsewhere: drop them from the selection.
          selected: state.selected.where(ids.contains).toSet(),
        ),
      );
    });
    unawaited(previous?.cancel());
  }

  @override
  Future<void> close() async {
    _searchTimer?.cancel();
    await _sub?.cancel();
    return super.close();
  }
}
