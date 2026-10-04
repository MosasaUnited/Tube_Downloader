import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tube_downloader/core/database/tables/app_settings_table.dart';
import 'package:tube_downloader/core/database/tables/download_tables.dart';
import 'package:tube_downloader/core/database/tables/library_items_table.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/error/failure_type.dart';

part 'app_database.g.dart';

/// The app's single database: queue, library, settings.
///
/// Schema changes go through `dart run drift_dev make-migrations` (build.yaml):
/// bump [schemaVersion], write the step, and the generated SchemaVerifier test
/// proves it. Migrations only ever add — never drop user data.
@DriftDatabase(
  tables: [
    DownloadGroups,
    DownloadTasks,
    TaskLegs,
    TaskEvents,
    LibraryItems,
    AppSettingsTable,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// [executor] is injected by tests (`NativeDatabase.memory()`).
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openDefault());

  static QueryExecutor _openDefault() => driftDatabase(
    name: 'tube_downloader',
    // Application Support, NOT Documents: on iOS, Documents is exposed in the
    // Files app (that is where downloads go) — the database must not be.
    native: const DriftNativeOptions(
      databaseDirectory: getApplicationSupportDirectory,
    ),
  );

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await into(appSettingsTable).insert(defaultSettingsRow);
    },
    beforeOpen: (details) async {
      // SQLite leaves foreign keys off per connection; the cascades need them.
      await customStatement('PRAGMA foreign_keys = ON');
    },
  );

  /// The settings row for a fresh install — the [AppSettings] defaults.
  static AppSettingsTableCompanion get defaultSettingsRow {
    const s = AppSettings();
    return AppSettingsTableCompanion.insert(
      id: const Value(1),
      saveDirectory: Value(s.saveDirectory),
      defaultKind: s.defaultKind,
      defaultMaxHeight: s.defaultMaxHeight,
      audioKbps: s.audioKbps,
      maxConcurrent: s.maxConcurrent,
      nameTemplate: s.nameTemplate,
      playlistSubfolders: s.playlistSubfolders,
      wifiOnly: s.wifiOnly,
      clipboardWatch: s.clipboardWatch,
      notifications: s.notifications,
      theme: s.theme,
      languageCode: Value(s.languageCode),
    );
  }
}
