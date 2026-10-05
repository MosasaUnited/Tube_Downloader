import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Licences Flutter can't collect by itself (it gathers every package's
/// LICENSE file automatically): the bundled Almarai font (SIL OFL 1.1, which
/// must travel with the font) and the FFmpeg source notice the LGPL asks for.
/// Shown on Settings › Open-source licenses.
void registerExtraLicenses() {
  LicenseRegistry.addLicense(() async* {
    yield LicenseEntryWithLineBreaks(const [
      'Almarai font',
    ], await rootBundle.loadString('assets/fonts/OFL.txt'));
    yield const LicenseEntryWithLineBreaks(['FFmpeg'], _ffmpegNotice);
  });
}

const _ffmpegNotice = '''
Tube Downloader merges and converts media with FFmpeg (https://ffmpeg.org) through FFmpegKit for Flutter, audio variant 2.5.4 (https://github.com/sk3llo/ffmpeg_kit_flutter).

FFmpeg and FFmpegKit are licensed under the GNU Lesser General Public License, version 3 (full text under ffmpeg_kit_flutter_new_audio on this page). This variant contains no GPL-licensed codecs.

They are used unmodified, as separate dynamically linked libraries that can be replaced. Their complete source code is available at the addresses above.''';
