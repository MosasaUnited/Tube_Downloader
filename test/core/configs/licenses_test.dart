import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/configs/licenses.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'the licences page lists the Almarai OFL and the FFmpeg notice',
    () async {
      registerExtraLicenses();
      final entries = await LicenseRegistry.licenses.toList();
      String textOf(String package) => entries
          .firstWhere((e) => e.packages.contains(package))
          .paragraphs
          .map((p) => p.text)
          .join('\n');

      expect(textOf('Almarai font'), contains('SIL Open Font License'));
      final ffmpeg = textOf('FFmpeg');
      expect(ffmpeg, contains('Lesser General Public License'));
      expect(ffmpeg, contains('https://github.com/sk3llo/ffmpeg_kit_flutter'));
    },
  );
}
