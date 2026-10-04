import 'package:drift/drift.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';

/// Exactly one row (id = 1), inserted when the database is created.
@DataClassName('AppSettingsRow')
class AppSettingsTable extends Table {
  @override
  String get tableName => 'app_settings';

  IntColumn get id => integer()();
  TextColumn get saveDirectory => text().nullable()();
  TextColumn get defaultKind => textEnum<MediaKind>()();
  IntColumn get defaultMaxHeight => integer()();
  IntColumn get audioKbps => integer()();
  IntColumn get maxConcurrent => integer()();
  TextColumn get nameTemplate => text()();
  BoolColumn get playlistSubfolders => boolean()();
  BoolColumn get wifiOnly => boolean()();
  BoolColumn get clipboardWatch => boolean()();
  BoolColumn get notifications => boolean()();
  TextColumn get theme => textEnum<ThemePreference>()();
  TextColumn get languageCode => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  // Table-level so the columns needn't reference themselves (recursive_getters).
  @override
  List<String> get customConstraints => [
    'CHECK (id = 1)',
    // drift reads these statically: literals only (interpolation is dropped).
    // Keep in sync with AppSettings.minConcurrent / maxConcurrentLimit.
    'CHECK (max_concurrent BETWEEN 1 AND 5)',
  ];
}
