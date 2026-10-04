/// Exceptions the app throws itself. Each one maps to exactly one
/// `FailureType` in `FailureMapper`, so data-layer code can fail precisely
/// without building an `AppFailure` by hand.
library;

/// The user (or the queue) cancelled the operation. Never shown.
final class CancelledException implements Exception {
  const CancelledException();
}

/// The pasted text is not a link this app can resolve.
final class UnsupportedLinkException implements Exception {
  const UnsupportedLinkException(this.input);
  final String input;
}

/// An HTTP response the transport could not use.
final class HttpStatusException implements Exception {
  const HttpStatusException(this.statusCode, {this.uri});
  final int statusCode;
  final Uri? uri;

  @override
  String toString() => 'HttpStatusException($statusCode)';
}

/// FFmpeg finished with a non-zero return code.
final class FfmpegException implements Exception {
  const FfmpegException(this.returnCode, {this.logTail});
  final int? returnCode;

  /// The last lines of the FFmpeg log — for `AppFailure.debug` only.
  final String? logTail;

  @override
  String toString() => 'FfmpegException(rc: $returnCode)';
}
