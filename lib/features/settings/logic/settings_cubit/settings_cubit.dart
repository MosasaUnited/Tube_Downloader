import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/repos/file_system_gateway.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/platform/folder_picker.dart';
import 'package:tube_downloader/core/platform/notification_service.dart';
import 'package:tube_downloader/features/settings/logic/settings_cubit/settings_state.dart';

/// Everything on the Settings screen except theme and language (those are
/// the app-root AppearanceCubit's). Setters return the [Result] so a failed
/// save is reported next to the control.
class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit(this._settings, this._fs, this._picker, this._notifications)
    : super(SettingsState(settings: _settings.current));

  final SettingsRepo _settings;
  final FileSystemGateway _fs;
  final FolderPicker _picker;
  final NotificationService _notifications;
  StreamSubscription<AppSettings>? _sub;

  bool get canPickFolder => _picker.isSupported;

  void start() {
    _sub = _settings.watch().listen((settings) {
      if (isClosed) return;
      final folderChanged =
          settings.saveDirectory != state.settings.saveDirectory;
      emit(state.copyWith(settings: settings));
      if (folderChanged) unawaited(refreshStorage());
    });
    unawaited(refreshStorage());
  }

  /// Re-reads the save folder and its free space.
  Future<void> refreshStorage() async {
    final folder = await _fs.saveDirectory();
    final space = await _fs.space();
    if (isClosed) return;
    emit(state.copyWith(saveDirectory: folder, space: space));
  }

  /// Opens the folder chooser; returns the failure to report (null when it
  /// worked or the user cancelled).
  Future<AppFailure?> pickFolder() async {
    final picked = await _picker.pick(initialDirectory: state.saveDirectory);
    if (isClosed) return null;
    switch (picked) {
      case Failure(:final failure):
        return failure;
      case Success(:final data):
        if (data == null) return null;
        return _failureOf(
          await _update((s) => s.copyWith(saveDirectory: data)),
        );
    }
  }

  Future<Result<AppSettings>> resetFolder() =>
      _update((s) => s.copyWith(saveDirectory: null));

  Future<Result<AppSettings>> setDefaultKind(MediaKind kind) =>
      _update((s) => s.copyWith(defaultKind: kind));

  Future<Result<AppSettings>> setDefaultMaxHeight(int height) =>
      _update((s) => s.copyWith(defaultMaxHeight: height));

  Future<Result<AppSettings>> setAudioKbps(int kbps) =>
      _update((s) => s.copyWith(audioKbps: kbps));

  Future<Result<AppSettings>> setMaxConcurrent(int n) => _update(
    (s) => s.copyWith(
      maxConcurrent: n.clamp(
        AppSettings.minConcurrent,
        AppSettings.maxConcurrentLimit,
      ),
    ),
  );

  Future<Result<AppSettings>> setNameTemplate(String template) =>
      _update((s) => s.copyWith(nameTemplate: template.trim()));

  Future<Result<AppSettings>> setPlaylistSubfolders(bool value) =>
      _update((s) => s.copyWith(playlistSubfolders: value));

  Future<Result<AppSettings>> setWifiOnly(bool value) =>
      _update((s) => s.copyWith(wifiOnly: value));

  Future<Result<AppSettings>> setClipboardWatch(bool value) =>
      _update((s) => s.copyWith(clipboardWatch: value));

  Future<Result<AppSettings>> setNotifications(bool value) =>
      _update((s) => s.copyWith(notifications: value));

  /// Asks the system right after the user turns notifications on (the
  /// moment that explains the prompt). False when the system blocks them.
  Future<bool> requestNotificationPermission() =>
      _notifications.ensurePermission();

  Future<Result<AppSettings>> _update(
    AppSettings Function(AppSettings) change,
  ) => _settings.update(change);

  static AppFailure? _failureOf(Result<AppSettings> result) =>
      result is Failure<AppSettings> ? result.failure : null;

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
