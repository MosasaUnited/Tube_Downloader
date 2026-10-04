import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/database/app_database.dart';
import 'package:tube_downloader/core/download_core/data/repos/settings_repo_impl.dart';
import 'package:tube_downloader/core/download_core/domain/entities/app_settings.dart';
import 'package:tube_downloader/core/error/result.dart';

void main() {
  late AppDatabase db;
  late SettingsRepoImpl repo;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    repo = SettingsRepoImpl(db);
  });
  tearDown(() => db.close());

  test('a fresh database holds the default settings', () async {
    expect(await repo.load(), const AppSettings());
    expect(repo.current.theme, ThemePreference.dark);
  });

  test('update persists and is visible to a new repo instance', () async {
    await repo.load();
    final result = await repo.update(
      (s) => s.copyWith(theme: ThemePreference.light, languageCode: 'ar'),
    );
    expect(result, isA<Success<AppSettings>>());

    final fresh = await SettingsRepoImpl(db).load();
    expect(fresh.theme, ThemePreference.light);
    expect(fresh.languageCode, 'ar');
  });

  test('concurrency is clamped to what the database accepts (1–5)', () async {
    await repo.update((s) => s.copyWith(maxConcurrent: 9));
    expect(repo.current.maxConcurrent, 5);
    await repo.update((s) => s.copyWith(maxConcurrent: 0));
    expect(repo.current.maxConcurrent, 1);
  });

  test('watch emits the current value, then each change', () async {
    final emitted = <ThemePreference>[];
    final sub = repo.watch().listen((s) => emitted.add(s.theme));
    await pumpEventQueue();
    await repo.update((s) => s.copyWith(theme: ThemePreference.system));
    await pumpEventQueue();
    await sub.cancel();
    expect(emitted, [ThemePreference.dark, ThemePreference.system]);
  });
}
