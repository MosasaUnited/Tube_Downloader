import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/error/app_exceptions.dart';
import 'package:tube_downloader/core/error/failure_mapper.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// Stands in for package:http's ClientException, which the mapper matches by
/// type name so the app need not depend on package:http.
class ClientException implements Exception {
  ClientException(this.message);
  final String message;
  @override
  String toString() => 'ClientException: $message';
}

FailureType _posix(Object e) => FailureMapper.classify(e, isWindows: false);
FailureType _windows(Object e) => FailureMapper.classify(e, isWindows: true);

void main() {
  final id = VideoId('R6MlUcmOul8');

  group('own exceptions', () {
    test('cancel is silent', () {
      expect(_posix(const CancelledException()), FailureType.cancelled);
      expect(FailureType.cancelled.isSilent, isTrue);
    });
    test(
      'unsupported link',
      () => expect(
        _posix(const UnsupportedLinkException('x')),
        FailureType.unsupportedLink,
      ),
    );
    test(
      'ffmpeg',
      () => expect(_posix(const FfmpegException(1)), FailureType.ffmpegFailed),
    );
    test('HTTP statuses', () {
      expect(_posix(const HttpStatusException(403)), FailureType.streamExpired);
      expect(_posix(const HttpStatusException(410)), FailureType.streamExpired);
      expect(_posix(const HttpStatusException(429)), FailureType.rateLimited);
      expect(
        _posix(const HttpStatusException(404)),
        FailureType.videoUnavailable,
      );
      expect(
        _posix(const HttpStatusException(503)),
        FailureType.serverUnreachable,
      );
      expect(_posix(const HttpStatusException(418)), FailureType.unknown);
    });
  });

  group('youtube_explode_dart', () {
    test(
      'rate limit',
      () => expect(
        _posix(RequestLimitExceededException('429')),
        FailureType.rateLimited,
      ),
    );
    test(
      'paid video',
      () => expect(
        _posix(VideoRequiresPurchaseException(id)),
        FailureType.videoUnavailable,
      ),
    );
    test(
      'unavailable',
      () => expect(
        _posix(VideoUnavailableException.unavailable(id)),
        FailureType.videoUnavailable,
      ),
    );
    test('private', () {
      expect(
        _posix(
          VideoUnplayableException.unplayable(
            id,
            reason: 'This video is private',
          ),
        ),
        FailureType.privateVideo,
      );
    });
    test('age restricted', () {
      expect(
        _posix(
          VideoUnplayableException.unplayable(
            id,
            reason: 'Sign in to confirm your age',
          ),
        ),
        FailureType.ageRestricted,
      );
    });
    test('bot check is a rate limit, not age restriction', () {
      expect(
        _posix(
          VideoUnplayableException.unplayable(
            id,
            reason: "Sign in to confirm you're not a bot",
          ),
        ),
        FailureType.rateLimited,
      );
      expect(
        _posix(YoutubeExplodeException("Sign in to confirm you're not a bot")),
        FailureType.rateLimited,
      );
    });
    test(
      'live stream',
      () => expect(
        _posix(VideoUnplayableException.liveStream(id)),
        FailureType.liveNotSupported,
      ),
    );
    test('other unplayable', () {
      expect(
        _posix(
          VideoUnplayableException.unplayable(id, reason: 'Video unavailable'),
        ),
        FailureType.videoUnavailable,
      );
    });
    test('transient watch-page failure is retryable', () {
      final type = _posix(
        TransientFailureException(
          'Failed to retrieve initial data from WatchPage',
        ),
      );
      expect(type, FailureType.serverUnreachable);
      expect(type.isRetryable, isTrue);
    });
    test('bad video / playlist id', () {
      expect(
        _posix(_thrown(() => VideoId('not a video'))),
        FailureType.unsupportedLink,
      );
      expect(
        _posix(_thrown(() => PlaylistId('not a playlist'))),
        FailureType.unsupportedLink,
      );
    });
    test('an unrelated ArgumentError is not a link problem', () {
      expect(_posix(ArgumentError.value(1, 'count')), FailureType.unknown);
    });
  });

  group('file system', () {
    test('POSIX disk full / permission', () {
      expect(
        _posix(
          const FileSystemException('w', 'p', OSError('No space left', 28)),
        ),
        FailureType.storageFull,
      );
      expect(
        _posix(
          const FileSystemException('w', 'p', OSError('Permission denied', 13)),
        ),
        FailureType.permissionDenied,
      );
      expect(
        _posix(
          const FileSystemException(
            'w',
            'p',
            OSError('Operation not permitted', 1),
          ),
        ),
        FailureType.permissionDenied,
      );
    });
    test('Windows disk full / access denied', () {
      expect(
        _windows(
          const FileSystemException('w', 'p', OSError('disk full', 112)),
        ),
        FailureType.storageFull,
      );
      expect(
        _windows(
          const FileSystemException('w', 'p', OSError('handle disk full', 39)),
        ),
        FailureType.storageFull,
      );
      expect(
        _windows(
          const FileSystemException('w', 'p', OSError('Access is denied', 5)),
        ),
        FailureType.permissionDenied,
      );
    });
    test('the same code means different things per OS', () {
      // POSIX 5 is EIO, Windows 5 is ERROR_ACCESS_DENIED.
      expect(
        _posix(const FileSystemException('w', 'p', OSError('I/O error', 5))),
        FailureType.unknown,
      );
    });
  });

  group('network', () {
    test('DNS failure means offline', () {
      expect(
        _posix(const SocketException('Failed host lookup: www.youtube.com')),
        FailureType.noInternet,
      );
      expect(
        _posix(ClientException('Failed host lookup: www.youtube.com')),
        FailureType.noInternet,
      );
    });
    test('refused / reset / timeout means the server side', () {
      expect(
        _posix(const SocketException('Connection refused')),
        FailureType.serverUnreachable,
      );
      expect(
        _posix(ClientException('Connection reset by peer')),
        FailureType.serverUnreachable,
      );
      expect(_posix(TimeoutException('stall')), FailureType.serverUnreachable);
      expect(
        _posix(const HandshakeException('bad cert')),
        FailureType.serverUnreachable,
      );
    });
  });

  test('anything else is unknown, and debug carries the detail', () {
    final failure = FailureMapper.map(StateError('boom'), null, false);
    expect(failure.type, FailureType.unknown);
    expect(failure.debug, contains('boom'));
  });
}

Object _thrown(void Function() f) {
  try {
    f();
  } on Object catch (e) {
    return e;
  }
  fail('expected a throw');
}
