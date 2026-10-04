import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_cubit.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_state.dart';

void main() {
  late AppDatabase db;
  late SettingsRepoImpl repo;

  setUp(() async {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepoImpl(db);
    await repo.load();
  });
  tearDown(() => db.close());

  test('starts from the loaded settings — no theme flash on launch', () async {
    final cubit = AppearanceCubit(repo);
    expect(cubit.state, const AppearanceState(themeMode: ThemeMode.dark));
    await cubit.close();
  });

  test(
    'theme and language changes arrive through the settings stream',
    () async {
      final cubit = AppearanceCubit(repo);
      final states = <AppearanceState>[];
      final sub = cubit.stream.listen(states.add);

      await cubit.setTheme(ThemePreference.light);
      await pumpEventQueue();
      await cubit.setLanguage('ar');
      await pumpEventQueue();

      expect(
        states.last,
        const AppearanceState(themeMode: ThemeMode.light, locale: Locale('ar')),
      );
      expect(states.map((s) => s.themeMode), contains(ThemeMode.light));
      await sub.cancel();
      await cubit.close();
    },
  );

  test(
    'a change after close() is ignored, not a StateError (state-safety)',
    () async {
      final cubit = AppearanceCubit(repo);
      await cubit.close();
      // The settings stream fires after the cubit is gone; the cancelled
      // subscription must not emit.
      await repo.update((s) => s.copyWith(theme: ThemePreference.system));
      await pumpEventQueue();
      expect(cubit.isClosed, isTrue);
    },
  );
}
