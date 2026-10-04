import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/data/muxer/ffmpeg_commands.dart';

void main() {
  test(
    'merge copies video 0 and audio 1 without re-encoding; faststart for MP4',
    () {
      expect(
        FfmpegCommands.merge(
          videoPath: '/w/v.mp4',
          audioPath: '/w/a.m4a',
          outputPath: '/w/out.mp4',
        ),
        [
          '-y',
          '-hide_banner',
          '-nostdin',
          '-i',
          '/w/v.mp4',
          '-i',
          '/w/a.m4a', //
          '-map',
          '0:v:0',
          '-map',
          '1:a:0',
          '-c',
          'copy',
          '-movflags',
          '+faststart',
          '/w/out.mp4',
        ],
      );
    },
  );

  test('WebM output gets no MP4-only flags', () {
    expect(
      FfmpegCommands.merge(
        videoPath: 'v',
        audioPath: 'a',
        outputPath: 'out.webm',
      ),
      isNot(contains('-movflags')),
    );
  });

  test('MP3 conversion uses lame at the chosen bitrate', () {
    expect(
      FfmpegCommands.toMp3(
        audioPath: 'a.m4a',
        outputPath: 'out.mp3',
        kbps: 192,
      ),
      containsAllInOrder(['-c:a', 'libmp3lame', '-b:a', '192k']),
    );
  });

  test('progress fraction from FFmpeg time', () {
    const d = Duration(seconds: 100);
    expect(FfmpegCommands.progressFraction(25000, d), 0.25);
    expect(FfmpegCommands.progressFraction(150000, d), 1.0);
    expect(FfmpegCommands.progressFraction(1000, null), isNull);
  });
}
