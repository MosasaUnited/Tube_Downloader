import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/theme/colors_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Desktop window setup (macOS, Windows): minimum size from the design
/// (1024×680), a dark background so there is no white flash before the first
/// frame (flutter-splash-launch skill), and the flavour's title.
abstract final class WindowService {
  static const minimumSize = Size(1024, 680);
  static const initialSize = Size(1280, 820);

  static bool get isDesktop => Platform.isMacOS || Platform.isWindows;

  static Future<void> configure(AppConfig config) async {
    if (!isDesktop) return;
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: initialSize,
      minimumSize: minimumSize,
      center: true,
      backgroundColor: ColorsManager.darkBackground,
      title: config.appName,
    );
    await windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
  }
}
