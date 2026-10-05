import 'package:get_it/get_it.dart';
import 'package:tube_downloader/features/library/domain/usecases/check_missing_files_use_case.dart';
import 'package:tube_downloader/features/library/domain/usecases/delete_library_items_use_case.dart';
import 'package:tube_downloader/features/library/logic/library_cubit/library_cubit.dart';

void registerLibraryDependencies(GetIt getIt) {
  getIt
    ..registerLazySingleton<CheckMissingFilesUseCase>(
      () => CheckMissingFilesUseCase(getIt(), getIt()),
    )
    ..registerLazySingleton<DeleteLibraryItemsUseCase>(
      () => DeleteLibraryItemsUseCase(getIt(), getIt(), getIt()),
    )
    ..registerFactory<LibraryCubit>(
      () => LibraryCubit(getIt(), getIt(), getIt(), getIt(), getIt()),
    );
}
