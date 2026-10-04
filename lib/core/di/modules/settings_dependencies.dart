import 'package:get_it/get_it.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_cubit.dart';

void registerSettingsDependencies(GetIt getIt) {
  // App-root singleton: MaterialApp rebuilds from it (theme + locale).
  getIt.registerLazySingleton<AppearanceCubit>(
    () => AppearanceCubit(getIt()),
    dispose: (cubit) => cubit.close(),
  );
}
