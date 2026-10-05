import 'package:freezed_annotation/freezed_annotation.dart';

part 'storage_space.freezed.dart';

/// Free and total bytes of the volume downloads are saved to.
@freezed
abstract class StorageSpace with _$StorageSpace {
  const factory StorageSpace({
    required int freeBytes,
    required int totalBytes,
  }) = _StorageSpace;

  const StorageSpace._();

  /// 0–1 for the storage meter.
  double get usedFraction =>
      totalBytes <= 0 ? 0 : (1 - freeBytes / totalBytes).clamp(0, 1);
}
