import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';

part 'storage_meter_state.freezed.dart';

@freezed
abstract class StorageMeterState with _$StorageMeterState {
  const factory StorageMeterState({String? folder, StorageSpace? space}) =
      _StorageMeterState;
}
