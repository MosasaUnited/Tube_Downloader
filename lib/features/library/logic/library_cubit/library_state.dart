import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';

part 'library_state.freezed.dart';

enum LibraryView { grid, list }

@freezed
abstract class LibraryState with _$LibraryState {
  const factory LibraryState({
    /// Everything matching [query] (any kind) — the chips count from it.
    @Default(<LibraryItem>[]) List<LibraryItem> matches,
    @Default('') String query,

    /// null = All.
    MediaKind? kind,
    @Default(LibrarySort.newest) LibrarySort sort,
    @Default(LibraryView.grid) LibraryView view,
    @Default(false) bool selecting,
    @Default(<String>{}) Set<String> selected,

    /// False until the first list arrives (no empty-state flash).
    @Default(false) bool loaded,
  }) = _LibraryState;
}

extension LibraryStateX on LibraryState {
  List<LibraryItem> get visible =>
      kind == null ? matches : matches.where((i) => i.kind == kind).toList();

  int countOf(MediaKind? of) =>
      of == null ? matches.length : matches.where((i) => i.kind == of).length;

  List<LibraryItem> get selectedItems =>
      matches.where((i) => selected.contains(i.id)).toList();

  int get selectedBytes => selectedItems.fold(0, (sum, i) => sum + i.bytes);

  /// Photos takes videos only.
  bool get selectionHasVideo =>
      selectedItems.any((i) => i.kind == MediaKind.video && !i.missing);
}
