import 'package:drift/drift.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/error/failure_type.dart';

/// One row per playlist download ("Lo-fi Beats · 12 of 32 done").
@DataClassName('DownloadGroupRow')
class DownloadGroups extends Table {
  TextColumn get id => text()();
  TextColumn get playlistId => text()();
  TextColumn get title => text()();
  TextColumn get channel => text().nullable()();

  /// Subfolder under the save directory when "playlist subfolders" is on.
  TextColumn get subDir => text().nullable()();
  IntColumn get total => integer()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// The download queue. Durable state only — live bytes/speed stream from the
/// queue service, not from this table.
@DataClassName('DownloadTaskRow')
@TableIndex(name: 'tasks_runnable', columns: {#status, #notBefore, #position})
@TableIndex(name: 'tasks_group', columns: {#groupId})
@TableIndex(name: 'tasks_dedupe', columns: {#videoId, #formatKey})
class DownloadTasks extends Table {
  TextColumn get id => text()();
  TextColumn get groupId => text().nullable().references(
    DownloadGroups,
    #id,
    onDelete: KeyAction.cascade,
  )();
  IntColumn get position => integer()();
  IntColumn get playlistIndex => integer().nullable()();
  TextColumn get sourceUrl => text()();
  TextColumn get videoId => text()();
  TextColumn get title => text()();
  TextColumn get channel => text()();
  IntColumn get durationMs => integer().nullable()();
  TextColumn get thumbUrl => text().nullable()();

  /// The persisted FormatSelector (versioned JSON) — never an itag or a URL.
  TextColumn get formatJson => text()();

  /// Stable key of the selector, for duplicate detection with [videoId].
  TextColumn get formatKey => text()();
  TextColumn get status => textEnum<TaskStatus>()();
  TextColumn get pauseReason => textEnum<PauseReason>().nullable()();
  TextColumn get failureType => textEnum<FailureType>().nullable()();

  /// Technical detail for logs; never shown.
  TextColumn get failureDebug => text().nullable()();
  IntColumn get attempt => integer().withDefault(const Constant(0))();

  /// Backoff: the task is runnable again after this time.
  DateTimeColumn get notBefore => dateTime().nullable()();
  TextColumn get outputPath => text().nullable()();
  TextColumn get transport => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Per-stream progress of a task, checkpointed for resume and recovery.
@DataClassName('TaskLegRow')
class TaskLegs extends Table {
  TextColumn get taskId =>
      text().references(DownloadTasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get kind => textEnum<LegKind>()();
  IntColumn get itag => integer().nullable()();
  TextColumn get ext => text().nullable()();
  TextColumn get url => text().nullable()();
  DateTimeColumn get urlExpiresAt => dateTime().nullable()();
  IntColumn get totalBytes => integer().nullable()();
  IntColumn get doneBytes => integer().withDefault(const Constant(0))();
  TextColumn get tmpPath => text()();
  TextColumn get transportRef => text().nullable()();
  BoolColumn get completed => boolean().withDefault(const Constant(false))();

  @override
  Set<Column<Object>> get primaryKey => {taskId, kind};
}

/// The task timeline (type + args; the UI localizes it).
@DataClassName('TaskEventRow')
@TableIndex(name: 'events_task_time', columns: {#taskId, #at})
class TaskEvents extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get taskId =>
      text().references(DownloadTasks, #id, onDelete: KeyAction.cascade)();
  TextColumn get type => textEnum<EventType>()();
  DateTimeColumn get at => dateTime()();
  TextColumn get argsJson => text().nullable()();
}
