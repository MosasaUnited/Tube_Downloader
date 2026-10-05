import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:tube_downloader/core/download_core/domain/entities/storage_space.dart';

typedef _GetDiskFreeSpaceExNative = Int32 Function(
  Pointer<Utf16> directory,
  Pointer<Uint64> freeToCaller,
  Pointer<Uint64> total,
  Pointer<Uint64> totalFree,
);
typedef _GetDiskFreeSpaceExDart = int Function(
  Pointer<Utf16> directory,
  Pointer<Uint64> freeToCaller,
  Pointer<Uint64> total,
  Pointer<Uint64> totalFree,
);

/// GetDiskFreeSpaceExW from kernel32 (Windows only — the library is opened
/// at call time, so this file compiles on every platform). "Free" is what is
/// available to this user, which respects disk quotas.
StorageSpace? windowsDiskSpace(String path) {
  final getSpace = DynamicLibrary.open('kernel32.dll')
      .lookupFunction<_GetDiskFreeSpaceExNative, _GetDiskFreeSpaceExDart>(
        'GetDiskFreeSpaceExW',
      );
  final directory = path.toNativeUtf16();
  final free = calloc<Uint64>();
  final total = calloc<Uint64>();
  final totalFree = calloc<Uint64>();
  try {
    final ok = getSpace(directory, free, total, totalFree);
    return ok == 0
        ? null
        : StorageSpace(freeBytes: free.value, totalBytes: total.value);
  } finally {
    calloc
      ..free(directory)
      ..free(free)
      ..free(total)
      ..free(totalFree);
  }
}
