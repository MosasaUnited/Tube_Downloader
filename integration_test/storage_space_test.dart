import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:tube_downloader/core/download_core/data/platform/volume_space_probe.dart';

/// The Runner's storage channel inside the real app (Swift / Kotlin).
///   flutter test integration_test/storage_space_test.dart -d macos --flavor development
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('free and total space of a real volume', (tester) async {
    final space = await const PlatformVolumeSpaceProbe().spaceOf(
      '${Directory.systemTemp.path}/not-created-yet/sub',
    );
    expect(space, isNotNull);
    expect(space!.totalBytes, greaterThan(1024 * 1024 * 1024));
    expect(space.freeBytes, inInclusiveRange(1, space.totalBytes));
    // ignore: avoid_print — the numbers, for the record.
    print('[it] free ${space.freeBytes} of ${space.totalBytes}');
  });
}
