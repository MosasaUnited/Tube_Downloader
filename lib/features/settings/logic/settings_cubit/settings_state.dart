import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';

part 'settings_state.freezed.dart';

@freezed
abstract class SettingsState with _$SettingsState {
  const factory SettingsState({
    required AppSettings settings,

    /// The folder downloads go to now (chosen or default); null until read.
    String? saveDirectory,

    /// Its volume's free / total space; null when unknown.
    StorageSpace? space,
  }) = _SettingsState;
}
