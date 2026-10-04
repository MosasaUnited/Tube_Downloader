import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';

part 'app_settings.freezed.dart';

/// Theme preference, kept free of Flutter's `ThemeMode` so the domain stays
/// pure Dart; the appearance cubit maps it.
enum ThemePreference { system, light, dark }

/// Everything the Settings screen edits. One row in drift (`app_settings`).
@freezed
abstract class AppSettings with _$AppSettings {
  const factory AppSettings({
    /// null = the platform default folder (decided by FileSystemGateway).
    String? saveDirectory,
    @Default(MediaKind.video) MediaKind defaultKind,
    @Default(1080) int defaultMaxHeight,
    @Default(192) int audioKbps,
    @Default(2) int maxConcurrent,
    @Default('{title} - {channel}') String nameTemplate,
    @Default(true) bool playlistSubfolders,
    @Default(false) bool wifiOnly,
    @Default(true) bool clipboardWatch,
    @Default(true) bool notifications,
    @Default(ThemePreference.dark) ThemePreference theme,

    /// Language code ('en' / 'ar'); null follows the device.
    String? languageCode,
  }) = _AppSettings;

  const AppSettings._();

  static const minConcurrent = 1;
  static const maxConcurrentLimit = 5;
}
