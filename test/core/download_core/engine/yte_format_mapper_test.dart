import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/yte_format_mapper.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';

/// Shaped like Big Buck Bunny's manifest (docs/spike/phase0.md).
const _manifest = [
  StreamCandidate(
    itag: 701,
    leg: LegKind.video,
    container: 'mp4',
    bytes: 900,
    kbps: 9000,
    codec: 'av01.0.13M.08',
    height: 2160,
    fps: 60,
    qualityLabel: '2160p60',
  ),
  StreamCandidate(
    itag: 315,
    leg: LegKind.video,
    container: 'webm',
    bytes: 950,
    kbps: 9500,
    codec: 'vp9',
    height: 2160,
    fps: 60,
    qualityLabel: '2160p60',
  ),
  StreamCandidate(
    itag: 299,
    leg: LegKind.video,
    container: 'mp4',
    bytes: 250,
    kbps: 4000,
    codec: 'avc1.64002a',
    height: 1080,
    fps: 60,
    qualityLabel: '1080p60',
  ),
  StreamCandidate(
    itag: 137,
    leg: LegKind.video,
    container: 'mp4',
    bytes: 200,
    kbps: 3000,
    codec: 'avc1.640028',
    height: 1080,
    fps: 30,
    qualityLabel: '1080p',
  ),
  StreamCandidate(
    itag: 248,
    leg: LegKind.video,
    container: 'webm',
    bytes: 180,
    kbps: 2800,
    codec: 'vp9',
    height: 1080,
    fps: 30,
    qualityLabel: '1080p',
  ),
  StreamCandidate(
    itag: 136,
    leg: LegKind.video,
    container: 'mp4',
    bytes: 120,
    kbps: 1500,
    codec: 'avc1.4d401f',
    height: 720,
    fps: 30,
    qualityLabel: '720p',
  ),
  StreamCandidate(
    itag: 134,
    leg: LegKind.video,
    container: 'mp4',
    bytes: 40,
    kbps: 500,
    codec: 'avc1.4d401e',
    height: 360,
    fps: 30,
    qualityLabel: '360p',
  ),
  StreamCandidate(
    itag: 140,
    leg: LegKind.audio,
    container: 'mp4',
    bytes: 1600000,
    kbps: 128,
    codec: 'mp4a.40.2',
  ),
  StreamCandidate(
    itag: 139,
    leg: LegKind.audio,
    container: 'mp4',
    bytes: 600000,
    kbps: 49,
    codec: 'mp4a.40.5',
  ),
  StreamCandidate(
    itag: 251,
    leg: LegKind.audio,
    container: 'webm',
    bytes: 2000000,
    kbps: 160,
    codec: 'opus',
  ),
  StreamCandidate(
    itag: 18,
    leg: LegKind.muxed,
    container: 'mp4',
    bytes: 30,
    kbps: 600,
    codec: 'avc1.42001E',
    height: 360,
    fps: 30,
    qualityLabel: '360p',
  ),
];

FormatSelector _video(
  int maxHeight, {
  bool hfr = false,
  OutContainer container = OutContainer.mp4,
}) => FormatSelector(
  kind: MediaKind.video,
  container: container,
  maxHeight: maxHeight,
  preferHighFps: hfr,
);

void main() {
  group('picker rows', () {
    final options = YteFormatMapper.options(_manifest);
    final video = options.where((o) => o.kind == MediaKind.video).toList();
    final audio = options.where((o) => o.kind == MediaKind.audio).toList();

    test('one row per height, highest first', () {
      expect(video.map((o) => o.height), [2160, 1080, 720, 360]);
    });

    test('4K has no H.264: AV1 in MP4 beats VP9 in WebM', () {
      expect(video.first.container, OutContainer.mp4);
      expect(video.first.videoCodec, startsWith('av01'));
      expect(video.first.selector.codec, VideoCodecPreference.any);
    });

    test(
      '1080p prefers H.264 at the higher frame rate; size includes the audio',
      () {
        final row = video[1];
        expect(row.label, '1080p60');
        expect(row.selector, _video(1080, hfr: true));
        expect(row.estimatedBytes, 250 + 1600000, reason: 'video + best AAC');
        expect(row.requiresMerge, isTrue);
      },
    );

    test(
      'audio rows: M4A, then MP3 at 320 / 192 / 128 with size estimates',
      () {
        expect(audio.map((o) => '${o.label} ${o.bitrateKbps}'), [
          'M4A 128',
          'MP3 320',
          'MP3 192',
          'MP3 128',
        ]);
        expect(
          audio
              .skip(1)
              .every((o) => o.requiresTranscode && o.estimatedBytes != null),
          isTrue,
        );
        // 2,000,000 B of 160 kb/s opus = 100 s → 192 kb/s MP3 ≈ 2.4 MB.
        expect(audio[2].estimatedBytes, 2400000);
      },
    );

    test('a manifest with only the muxed stream offers it without a merge', () {
      final muxedOnly = YteFormatMapper.options(
        _manifest.where((s) => s.leg == LegKind.muxed).toList(),
      );
      expect(muxedOnly.single.requiresMerge, isFalse);
      expect(muxedOnly.single.height, 360);
    });
  });

  group('plans', () {
    test('video → video + audio legs; audio → audio leg', () {
      expect(YteFormatMapper.plan(_manifest, _video(1080)), [
        LegKind.video,
        LegKind.audio,
      ]);
      expect(
        YteFormatMapper.plan(
          _manifest,
          const FormatSelector(
            kind: MediaKind.audio,
            container: OutContainer.mp3,
            audioKbps: 192,
          ),
        ),
        [LegKind.audio],
      );
    });

    test('no separate streams → one muxed leg; nothing at all → null', () {
      final muxedOnly = _manifest.where((s) => s.leg == LegKind.muxed).toList();
      expect(YteFormatMapper.plan(muxedOnly, _video(1080)), [LegKind.muxed]);
      expect(YteFormatMapper.plan(const [], _video(1080)), isNull);
    });
  });

  group('picks', () {
    StreamCandidate pick(FormatSelector s, LegKind leg) =>
        YteFormatMapper.pick(_manifest, s, leg)!;

    test('height cap and frame-rate preference', () {
      expect(pick(_video(1080, hfr: true), LegKind.video).itag, 299);
      expect(
        pick(_video(1080), LegKind.video).itag,
        137,
        reason: 'standard frame rate when not asked for 60',
      );
      expect(pick(_video(720), LegKind.video).itag, 136);
    });

    test('H.264 is preferred in MP4 even when AV1 is higher', () {
      expect(
        pick(_video(2160, hfr: true), LegKind.video).itag,
        299,
        reason: 'best H.264 ≤ 2160 is the 1080p60',
      );
      expect(
        pick(_video(2160), LegKind.video).itag,
        137,
        reason: 'without a 60 fps preference: the 30 fps stream',
      );
      final any = const FormatSelector(
        kind: MediaKind.video,
        container: OutContainer.mp4,
        maxHeight: 2160,
        codec: VideoCodecPreference.any,
      );
      expect(pick(any, LegKind.video).itag, 701);
    });

    test('audio follows the output container', () {
      expect(
        pick(_video(1080), LegKind.audio).itag,
        140,
        reason: 'AAC for MP4',
      );
      expect(
        pick(_video(1080, container: OutContainer.webm), LegKind.audio).itag,
        251,
        reason: 'Opus for WebM',
      );
      expect(
        pick(
          const FormatSelector(
            kind: MediaKind.audio,
            container: OutContainer.m4a,
          ),
          LegKind.audio,
        ).itag,
        140,
      );
    });

    test('a cap below every stream takes the smallest available', () {
      expect(pick(_video(144), LegKind.video).itag, 134);
    });
  });
}
