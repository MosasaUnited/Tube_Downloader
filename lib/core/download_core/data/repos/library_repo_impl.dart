import 'package:drift/drift.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/library_item.dart';
import 'package:tube_downloader/core/download_core/domain/repos/library_repo.dart';
import 'package:tube_downloader/core/download_core/domain/search/search_normalizer.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/result.dart';

/// [LibraryRepo] on drift.
class LibraryRepoImpl implements LibraryRepo {
  LibraryRepoImpl(this._db);

  final AppDatabase _db;

  @override
  Stream<List<LibraryItem>> watch({
    String query = '',
    MediaKind? kind,
    LibrarySort sort = LibrarySort.newest,
  }) {
    final l = _db.libraryItems;
    final needle = SearchNormalizer.normalize(query);
    final select = _db.select(l)
      ..where((r) {
        Expression<bool> condition = const Constant(true);
        if (needle.isNotEmpty) {
          condition = condition & r.searchNorm.contains(needle);
        }
        if (kind != null) condition = condition & r.kind.equalsValue(kind);
        return condition;
      })
      ..orderBy([
        (r) => switch (sort) {
          LibrarySort.newest => OrderingTerm.desc(r.completedAt),
          LibrarySort.oldest => OrderingTerm.asc(r.completedAt),
          LibrarySort.name => OrderingTerm.asc(r.searchNorm),
          LibrarySort.size => OrderingTerm.desc(r.bytes),
        },
      ]);
    return select.watch().map((rows) => [for (final r in rows) _toItem(r)]);
  }

  @override
  Future<List<LibraryItem>> all() async => [
    for (final r in await _db.select(_db.libraryItems).get()) _toItem(r),
  ];

  @override
  Future<Result<void>> add(LibraryItem item) async {
    try {
      await _db
          .into(_db.libraryItems)
          .insertOnConflictUpdate(
            LibraryItemsCompanion.insert(
              id: item.id,
              taskId: Value(item.taskId),
              videoId: item.videoId,
              sourceUrl: item.sourceUrl,
              title: item.title,
              channel: item.channel,
              searchNorm: SearchNormalizer.normalize(
                '${item.title} ${item.channel}',
              ),
              kind: item.kind,
              container: item.container,
              height: Value(item.height),
              durationMs: Value(item.duration?.inMilliseconds),
              path: item.path,
              bytes: item.bytes,
              thumbPath: Value(item.thumbPath),
              completedAt: item.completedAt,
              missing: Value(item.missing),
            ),
          );
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  @override
  Future<Result<void>> remove(Set<String> ids) async {
    try {
      await (_db.delete(_db.libraryItems)..where((r) => r.id.isIn(ids))).go();
      return const Result.success(null);
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  @override
  Future<void> setMissing(Set<String> ids, {required bool missing}) =>
      (_db.update(_db.libraryItems)..where((r) => r.id.isIn(ids))).write(
        LibraryItemsCompanion(missing: Value(missing)),
      );

  static LibraryItem _toItem(LibraryItemRow r) => LibraryItem(
    id: r.id,
    taskId: r.taskId,
    videoId: r.videoId,
    sourceUrl: r.sourceUrl,
    title: r.title,
    channel: r.channel,
    kind: r.kind,
    container: r.container,
    height: r.height,
    duration: r.durationMs == null
        ? null
        : Duration(milliseconds: r.durationMs!),
    path: r.path,
    bytes: r.bytes,
    thumbPath: r.thumbPath,
    completedAt: r.completedAt,
    missing: r.missing,
  );
}
