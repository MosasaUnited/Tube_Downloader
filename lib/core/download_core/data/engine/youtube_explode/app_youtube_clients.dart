import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// YouTube API clients the app defines itself.
abstract final class AppYoutubeClients {
  /// Apple Vision Pro — the only client whose adaptive audio AND video streams
  /// were fetchable without a PO token when this app was built (2026-10-04;
  /// youtube_explode_dart 3.1.0 issue #386, payload from upstream PR #389).
  /// Review when the package ships the client itself.
  static const visionOs = YoutubeApiClient({
    'context': {
      'client': {
        'clientName': 'VISIONOS',
        'clientVersion': '1.02',
        'deviceMake': 'Apple',
        'deviceModel': 'RealityDevice17,1',
        'osName': 'visionOS',
        'osVersion': '26.5.23O471',
        'userAgent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 15_7_3) AppleWebKit/605.1.15 '
            '(KHTML, like Gecko) Version/26.0 Safari/605.1.15',
        'hl': 'en',
        'timeZone': 'UTC',
        'utcOffsetMinutes': 0,
      },
    },
  }, 'https://www.youtube.com/youtubei/v1/player?prettyPrint=false');
}
