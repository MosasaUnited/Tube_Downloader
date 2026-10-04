@Tags(['network'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/download_core/data/engine/youtube_explode/yte_media_resolver.dart';
import 'package:tube_downloader/core/download_core/domain/entities/download_enums.dart';
import 'package:tube_downloader/core/download_core/domain/entities/format_selector.dart';
import 'package:tube_downloader/core/download_core/domain/entities/media_info.dart';
import 'package:tube_downloader/core/download_core/domain/link/link_parser.dart';
import 'package:tube_downloader/core/download_core/domain/services/resolve_gate.dart';
import 'package:tube_downloader/core/error/result.dart';

/// Real YouTube, real resolver. Local only: flutter test --tags network
/// Fixture: Tears of Steel (Blender Foundation, CC-BY).
void main() {
  late YteMediaResolver resolver;
  setUp(() => resolver = YteMediaResolver(gate: ResolveGate()));
  tearDown(() => resolver.close());

  T ok<T>(Result<T> r) => switch (r) {
    Success(:final data) => data,
    Failure(:final failure) => fail(
      'expected success, got ${failure.type}: ${failure.debug}',
    ),
  };

  test('link → metadata → formats → plan → a fetchable 720p stream', () async {
    final link = LinkParser.parse('https://youtu.be/R6MlUcmOul8');
    final resolved = ok(await resolver.resolve(link)) as ResolvedSingle;
    expect(resolved.media.title, contains('Tears of Steel'));
    expect(resolved.media.duration, isNotNull);

    final options = ok(await resolver.formats('R6MlUcmOul8'));
    expect(
      options.any(
        (o) => o.height == 1080 && (o.videoCodec ?? '').startsWith('avc1'),
      ),
      isTrue,
    );

    const selector = FormatSelector(
      kind: MediaKind.video,
      container: OutContainer.mp4,
      maxHeight: 720,
    );
    expect(ok(await resolver.plan('R6MlUcmOul8', selector)), [
      LegKind.video,
      LegKind.audio,
    ]);

    for (final leg in [LegKind.video, LegKind.audio]) {
      final target = ok(await resolver.target('R6MlUcmOul8', selector, leg));
      final client = HttpClient();
      final url = target.url.replace(
        queryParameters: {...target.url.queryParameters, 'range': '0-1023'},
      );
      final response = await (await client.getUrl(url)).close();
      await response.drain<void>();
      client.close(force: true);
      expect(
        response.statusCode,
        anyOf(200, 206),
        reason: '${leg.name} stream must be fetchable (visionOS client)',
      );
      expect(target.expiresAt?.isAfter(DateTime.now()), isTrue);
    }
  }, timeout: const Timeout(Duration(minutes: 2)));
}
