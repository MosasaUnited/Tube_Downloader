import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_state.dart';

/// Theme mode + language for the whole app. An app-root singleton (the whole
/// MaterialApp rebuilds from it), seeded from the settings loaded before
/// `runApp`, so the first frame already has the saved theme.
///
/// Setters return the [Result]: a failed save is rare, and the Settings screen
/// reports it next to the control the user just touched.
class AppearanceCubit extends Cubit<AppearanceState> {
  AppearanceCubit(this._settings) : super(_stateFrom(_settings.current)) {
    _sub = _settings.watch().listen((s) => emit(_stateFrom(s)));
  }

  final SettingsRepo _settings;
  late final StreamSubscription<AppSettings> _sub;

  Future<Result<AppSettings>> setTheme(ThemePreference theme) =>
      _settings.update((s) => s.copyWith(theme: theme));

  Future<Result<AppSettings>> setLanguage(String? languageCode) =>
      _settings.update((s) => s.copyWith(languageCode: languageCode));

  static AppearanceState _stateFrom(AppSettings s) => AppearanceState(
    themeMode: switch (s.theme) {
      ThemePreference.system => ThemeMode.system,
      ThemePreference.light => ThemeMode.light,
      ThemePreference.dark => ThemeMode.dark,
    },
    locale: s.languageCode == null ? null : Locale(s.languageCode!),
  );

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
