import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/error/result.dart';

/// Persistent app settings. Single source of truth for the Settings screen,
/// the appearance (theme + language) and the download queue's limits.
abstract interface class SettingsRepo {
  /// The latest settings (kept warm by [load] and [watch]); defaults until
  /// [load] completes.
  AppSettings get current;

  /// Reads the stored settings once. Bootstrap awaits it before `runApp`, so
  /// the first frame already has the saved theme and language.
  Future<AppSettings> load();

  /// Emits the current settings, then every change.
  Stream<AppSettings> watch();

  /// Applies [change] atomically and persists it.
  Future<Result<AppSettings>> update(
    AppSettings Function(AppSettings current) change,
  );
}
