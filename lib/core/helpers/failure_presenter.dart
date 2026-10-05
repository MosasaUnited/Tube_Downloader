import 'package:flutter/material.dart';
import 'package:tube_downloader/core/error/app_failure.dart';
import 'package:tube_downloader/core/error/failure_type.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/snackbar_helper.dart';

/// The localized sentence for a failure. Never includes [AppFailure.debug].
String failureMessage(BuildContext context, AppFailure failure) {
  final l10n = context.l10n;
  return switch (failure.type) {
    FailureType.noInternet => l10n.failureNoInternet,
    FailureType.serverUnreachable => l10n.failureServerUnreachable,
    FailureType.rateLimited => l10n.failureRateLimited,
    FailureType.unsupportedLink => l10n.failureUnsupportedLink,
    FailureType.videoUnavailable => l10n.failureVideoUnavailable,
    FailureType.privateVideo => l10n.failurePrivateVideo,
    FailureType.ageRestricted => l10n.failureAgeRestricted,
    FailureType.liveNotSupported => l10n.failureLiveNotSupported,
    FailureType.streamExpired => l10n.failureStreamExpired,
    FailureType.storageFull => l10n.failureStorageFull,
    FailureType.permissionDenied => l10n.failurePermissionDenied,
    FailureType.ffmpegFailed => l10n.failureFfmpegFailed,
    FailureType.fileMissing => l10n.failureFileMissing,
    FailureType.noAppToOpen => l10n.failureNoAppToOpen,
    FailureType.cancelled => l10n.failureCancelled,
    FailureType.unknown => l10n.failureUnknown,
  };
}

String? _lastShown;
DateTime? _lastShownAt;

/// One snackbar per failure branch (download-errors skill). Silent for
/// [FailureType.cancelled]; drops a repeat of the sentence already on screen
/// (several rows failing on the same offline event say it once).
void showFailureSnackBar(
  BuildContext context,
  AppFailure failure, {
  VoidCallback? onRetry,
}) {
  if (failure.isSilent) return;
  final message = failureMessage(context, failure);
  final now = DateTime.now();
  if (message == _lastShown &&
      _lastShownAt != null &&
      now.difference(_lastShownAt!) < const Duration(seconds: 3)) {
    return;
  }
  _lastShown = message;
  _lastShownAt = now;
  showInfoSnackBar(
    context,
    message,
    action: onRetry == null
        ? null
        : SnackBarAction(label: context.l10n.actionRetry, onPressed: onRetry),
  );
}

/// A blocking explanation for failures the user must acknowledge.
Future<void> showFailureDialog(BuildContext context, AppFailure failure) async {
  if (failure.isSilent) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      content: Text(failureMessage(dialogContext, failure)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(dialogContext.l10n.actionClose),
        ),
      ],
    ),
  );
}
