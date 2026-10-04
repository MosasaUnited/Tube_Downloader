import 'package:drift/drift.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/result.dart';

/// [SettingsRepo] on the single `app_settings` row.
class SettingsRepoImpl implements SettingsRepo {
  SettingsRepoImpl(this._db);

  final AppDatabase _db;
  AppSettings _current = const AppSettings();

  @override
  AppSettings get current => _current;

  @override
  Future<AppSettings> load() async {
    final row = await _db.select(_db.appSettingsTable).getSingleOrNull();
    return _current = row == null ? const AppSettings() : _toEntity(row);
  }

  @override
  Stream<AppSettings> watch() => _db
      .select(_db.appSettingsTable)
      .watchSingle()
      .map((row) => _current = _toEntity(row));

  @override
  Future<Result<AppSettings>> update(
    AppSettings Function(AppSettings current) change,
  ) async {
    try {
      // Read-modify-write in one transaction so two quick edits can't lose one.
      final next = await _db.transaction(() async {
        final row = await _db.select(_db.appSettingsTable).getSingle();
        final updated = _sanitize(change(_toEntity(row)));
        await _db.update(_db.appSettingsTable).replace(_toCompanion(updated));
        return updated;
      });
      _current = next;
      return Result.success(next);
    } on Object catch (e, s) {
      return Result.failure(FailureMapper.map(e, s));
    }
  }

  /// Keeps values inside what the database CHECK constraints accept.
  static AppSettings _sanitize(AppSettings s) => s.copyWith(
    maxConcurrent: s.maxConcurrent.clamp(
      AppSettings.minConcurrent,
      AppSettings.maxConcurrentLimit,
    ),
  );

  static AppSettings _toEntity(AppSettingsRow r) => AppSettings(
    saveDirectory: r.saveDirectory,
    defaultKind: r.defaultKind,
    defaultMaxHeight: r.defaultMaxHeight,
    audioKbps: r.audioKbps,
    maxConcurrent: r.maxConcurrent,
    nameTemplate: r.nameTemplate,
    playlistSubfolders: r.playlistSubfolders,
    wifiOnly: r.wifiOnly,
    clipboardWatch: r.clipboardWatch,
    notifications: r.notifications,
    theme: r.theme,
    languageCode: r.languageCode,
  );

  static AppSettingsTableCompanion _toCompanion(AppSettings s) =>
      AppSettingsTableCompanion(
        id: const Value(1),
        saveDirectory: Value(s.saveDirectory),
        defaultKind: Value(s.defaultKind),
        defaultMaxHeight: Value(s.defaultMaxHeight),
        audioKbps: Value(s.audioKbps),
        maxConcurrent: Value(s.maxConcurrent),
        nameTemplate: Value(s.nameTemplate),
        playlistSubfolders: Value(s.playlistSubfolders),
        wifiOnly: Value(s.wifiOnly),
        clipboardWatch: Value(s.clipboardWatch),
        notifications: Value(s.notifications),
        theme: Value(s.theme),
        languageCode: Value(s.languageCode),
      );
}
