import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/data/platform/volume_space_probe.dart';

void main() {
  test(
    'a folder that does not exist yet is measured at its nearest parent',
    () async {
      final dir = await Directory.systemTemp.createTemp('probe');
      addTearDown(() => dir.delete(recursive: true));
      expect(
        PlatformVolumeSpaceProbe.nearestExisting(
          '${dir.path}/Tube Downloader/Mix',
        ),
        dir.path,
      );
      expect(PlatformVolumeSpaceProbe.nearestExisting(dir.path), dir.path);
    },
  );

  test(
    'without the native channel (unit tests) the answer is unknown',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      expect(
        await const PlatformVolumeSpaceProbe().spaceOf(
          Directory.systemTemp.path,
        ),
        isNull,
      );
    },
  );
}
