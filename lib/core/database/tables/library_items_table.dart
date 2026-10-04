import 'package:drift/drift.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';

/// Finished files. Survives "clear completed" (no foreign key to the task).
@DataClassName('LibraryItemRow')
@TableIndex(name: 'library_kind_time', columns: {#kind, #completedAt})
@TableIndex(name: 'library_search', columns: {#searchNorm})
class LibraryItems extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable().unique()();
  TextColumn get videoId => text()();

  /// For "Copy link".
  TextColumn get sourceUrl => text()();
  TextColumn get title => text()();
  TextColumn get channel => text()();

  /// Lower-cased title + channel with Arabic diacritics / tatweel removed, so
  /// search matches what the user types.
  TextColumn get searchNorm => text()();
  TextColumn get kind => textEnum<MediaKind>()();
  TextColumn get container => textEnum<OutContainer>()();
  IntColumn get height => integer().nullable()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get path => text().unique()();
  IntColumn get bytes => integer()();

  /// Thumbnail saved locally at completion, so the library works offline.
  TextColumn get thumbPath => text().nullable()();
  DateTimeColumn get completedAt => dateTime()();

  /// The file was moved or deleted outside the app.
  BoolColumn get missing => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}
