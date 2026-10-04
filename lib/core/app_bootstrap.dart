import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/download_core/domain/repos/settings_repo.dart';
import 'package:tube_downloader/core/download_core/domain/services/download_queue_service.dart';
import 'package:tube_downloader/core/download_core/domain/services/recovery_service.dart';
import 'package:tube_downloader/core/platform/window_service.dart';
import 'package:tube_downloader/tube_downloader_app.dart';

/// Swallows the message. Installed as the global `debugPrint` in flavours with
/// [AppConfig.verboseLogging] off.
void _mutedDebugPrint(String? message, {int? wrapWidth}) {}

/// Applies [config]'s logging policy to the global `debugPrint` hook, and
/// returns the implementation that was in place beforehand.
///
/// `debugPrint` is a mutable top-level function pointer, not a compile-time
/// construct — so diagnostic call sites survive into release builds, and one
/// assignment here mutes all of them without editing any.
///
/// **Callers must use the returned function for anything that has to be visible
/// in production** (crash and uncaught-error reporting): muting also silences
/// the framework's own console dumps, so the return value is the only way back
/// to a real console.
@visibleForTesting
DebugPrintCallback installLoggingPolicy(AppConfig config) {
  // Idempotent: if a previous call already muted the hook, hand back the
  // framework default, never the no-op — returning the mute would sever error
  // reporting permanently.
  final previous = identical(debugPrint, _mutedDebugPrint)
      ? debugPrintThrottled
      : debugPrint;

  if (!config.verboseLogging) {
    debugPrint = _mutedDebugPrint;
  }
  return previous;
}

/// The startup pipeline shared by both flavour entry points.
///
/// **The order is load-bearing** (CLAUDE.md » Entry-point pipeline):
/// logging policy → window → DI (opens the database) → settings load (so the
/// first frame has the saved theme and language) → download recovery (rebuild
/// interrupted tasks from the bytes on disk) → queue start → `runApp`.
/// Recovery MUST finish before the queue pumps, or a half-recovered task could
/// be started twice.
///
/// Runs inside [runZonedGuarded] so an error during initialization is reported
/// instead of silently stranding the app before its first frame.
Future<void> bootstrapAndRun(AppConfig config) async {
  // Must happen before anything else can log, and the handle must be captured
  // into a LOCAL: a top-level `final` initialises lazily on first read — inside
  // the error handlers, after the swap — and would capture the muted no-op.
  final DebugPrintCallback reportToConsole = installLoggingPolicy(config);

  await runZonedGuarded(
    () async {
      WidgetsFlutterBinding.ensureInitialized();

      FlutterError.onError = (details) {
        // `presentError` dumps through `debugPrint` (a no-op when muted); the
        // explicit lines below are what survive in production.
        FlutterError.presentError(details);
        reportToConsole('Uncaught Flutter error: ${details.exception}');
        if (details.stack != null) reportToConsole('${details.stack}');
      };

      await WindowService.configure(config);
      await setupGetIt(config);
      await getIt<SettingsRepo>().load();
      await getIt<RecoveryService>().run();
      await getIt<DownloadQueueService>().start();

      runApp(TubeDownloaderApp(config: config));
    },
    (error, stackTrace) {
      reportToConsole('Uncaught zone error: $error');
      reportToConsole('$stackTrace');
    },
  );
}
