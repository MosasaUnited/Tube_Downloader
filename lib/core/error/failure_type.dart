/// Every way an operation can fail, as the UI needs to tell them apart.
///
/// Each value has a `failure<Type>` message in both ARB files, resolved by the
/// failure presenter — never a hard-coded string (download-errors skill).
enum FailureType {
  noInternet,
  serverUnreachable,
  rateLimited,
  unsupportedLink,
  videoUnavailable,
  privateVideo,
  ageRestricted,
  liveNotSupported,
  streamExpired,
  storageFull,
  permissionDenied,
  ffmpegFailed,

  /// A finished file was moved or deleted outside the app.
  fileMissing,
  cancelled,
  unknown;

  /// Shown to the user? A cancellation is the user's own action.
  bool get isSilent => this == FailureType.cancelled;

  /// Worth an automatic retry with backoff (the queue's policy) — the cause is
  /// expected to clear on its own.
  bool get isRetryable => switch (this) {
    noInternet || serverUnreachable || rateLimited || streamExpired => true,
    _ => false,
  };
}
