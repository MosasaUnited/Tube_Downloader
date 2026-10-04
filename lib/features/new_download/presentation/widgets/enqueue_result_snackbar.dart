import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/error/result.dart';
import 'package:tube_downloader/core/helpers/failure_presenter.dart';
import 'package:tube_downloader/core/helpers/l10n_extension.dart';
import 'package:tube_downloader/core/helpers/snackbar_helper.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/features/new_download/domain/usecases/enqueue_downloads_use_case.dart';

/// The one confirmation for every "Download" button on this tab: started
/// (with View → Downloads), already queued, or the failure.
void showEnqueueResult(BuildContext context, Result<EnqueueSummary> result) {
  final l10n = context.l10n;
  switch (result) {
    case Failure(:final failure):
      showFailureSnackBar(context, failure);
    case Success(:final data) when data.added == 0:
      showInfoSnackBar(context, l10n.alreadyInDownloads);
    case Success(:final data):
      final message = data.added == 1
          ? l10n.downloadStarted
          : l10n.downloadsAdded(data.added);
      showInfoSnackBar(
        context,
        data.skipped == 0
            ? message
            : '$message · ${l10n.alreadyQueuedCount(data.skipped)}',
        action: SnackBarAction(
          label: l10n.actionView,
          onPressed: () => context.go(AppRoutes.downloads),
        ),
      );
  }
}
