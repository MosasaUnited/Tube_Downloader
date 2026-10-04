import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:tube_downloader/core/error/app_exceptions.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:youtube_explode_dart/youtube_explode_dart.dart';

/// The ONLY place an exception becomes an [AppFailure] (download-errors skill).
///
/// The technical detail is logged with `debugPrint` (muted in production) and
/// kept in [AppFailure.debug]; the UI shows only the localized message for the
/// [FailureType]. Keep test/core/error/failure_mapper_test.dart in sync.
abstract final class FailureMapper {
  static AppFailure map(Object error, [StackTrace? stack, bool? isWindows]) {
    final type = classify(error, isWindows: isWindows ?? Platform.isWindows);
    if (!type.isSilent) {
      debugPrint('FailureMapper: ${error.runtimeType} → ${type.name}: $error');
      if (stack != null && type == FailureType.unknown) debugPrint('$stack');
    }
    return AppFailure(type: type, debug: '${error.runtimeType}: $error');
  }

  @visibleForTesting
  static FailureType classify(Object e, {required bool isWindows}) {
    return switch (e) {
      CancelledException() => FailureType.cancelled,
      UnsupportedLinkException() => FailureType.unsupportedLink,
      FfmpegException() => FailureType.ffmpegFailed,
      HttpStatusException(:final statusCode) => _fromHttpStatus(statusCode),

      // youtube_explode_dart 3.x — subclasses before their parents.
      RequestLimitExceededException() => FailureType.rateLimited,
      VideoRequiresPurchaseException() => FailureType.videoUnavailable,
      VideoUnavailableException() => FailureType.videoUnavailable,
      VideoUnplayableException(:final message) => _fromUnplayable(message),
      TransientFailureException() => FailureType.serverUnreachable,
      YoutubeExplodeException(:final message) when _isBotCheck(message) =>
        FailureType.rateLimited,
      // VideoId / PlaylistId parsing: ArgumentError.value(idOrUrl, 'idOrUrl', …).
      ArgumentError(name: 'idOrUrl') => FailureType.unsupportedLink,

      FileSystemException(:final osError) => _fromFileSystem(
        osError,
        isWindows,
      ),
      SocketException(:final message, :final osError) =>
        _isOffline(message, osError)
            ? FailureType.noInternet
            : FailureType.serverUnreachable,
      HandshakeException() ||
      TimeoutException() ||
      HttpException() => FailureType.serverUnreachable,
      // package:http's ClientException (youtube_explode's HTTP layer wraps socket
      // errors in it). Matched by name so the app need not depend on package:http,
      // which it never uses for requests; covered by the mapper test.
      _ when e.runtimeType.toString() == 'ClientException' =>
        _fromClientException('$e'),
      _ => FailureType.unknown,
    };
  }

  static FailureType _fromHttpStatus(int code) => switch (code) {
    403 || 410 => FailureType.streamExpired, // signed URL expired or IP changed
    429 => FailureType.rateLimited,
    404 => FailureType.videoUnavailable,
    >= 500 => FailureType.serverUnreachable,
    _ => FailureType.unknown,
  };

  /// YouTube's playability reason is embedded in the message ("Reason: …").
  static FailureType _fromUnplayable(String message) {
    final m = message.toLowerCase();
    if (_isBotCheck(m)) return FailureType.rateLimited;
    if (m.contains('ongoing live stream')) return FailureType.liveNotSupported;
    if (m.contains('confirm your age') ||
        m.contains('age-restricted') ||
        m.contains('inappropriate for some users')) {
      return FailureType.ageRestricted;
    }
    if (m.contains('private')) return FailureType.privateVideo;
    return FailureType.videoUnavailable;
  }

  static bool _isBotCheck(String message) =>
      message.toLowerCase().contains('not a bot');

  static FailureType _fromFileSystem(OSError? os, bool isWindows) {
    final code = os?.errorCode;
    if (code == null) return FailureType.unknown;
    if (isWindows) {
      // ERROR_DISK_FULL 112, ERROR_HANDLE_DISK_FULL 39, ERROR_ACCESS_DENIED 5.
      if (code == 112 || code == 39) return FailureType.storageFull;
      if (code == 5) return FailureType.permissionDenied;
      return FailureType.unknown;
    }
    // POSIX (macOS, iOS, Android): ENOSPC 28, EACCES 13, EPERM 1.
    if (code == 28) return FailureType.storageFull;
    if (code == 13 || code == 1) return FailureType.permissionDenied;
    return FailureType.unknown;
  }

  /// A failed DNS lookup or an unreachable network means the device is offline;
  /// refused / reset / timed-out connections mean the far side is the problem.
  static bool _isOffline(String message, OSError? os) {
    final text = '${message.toLowerCase()} ${os?.message.toLowerCase() ?? ''}';
    return text.contains('failed host lookup') ||
        text.contains('network is unreachable') ||
        text.contains('no address associated') ||
        text.contains('nodename nor servname');
  }

  static FailureType _fromClientException(String text) => _isOffline(text, null)
      ? FailureType.noInternet
      : FailureType.serverUnreachable;
}
