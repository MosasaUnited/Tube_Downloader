import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:tube_downloader/core/configs/app_config.dart';
import 'package:tube_downloader/core/di/dependency_injection.dart';
import 'package:tube_downloader/core/platform/notification_service.dart';
import 'package:tube_downloader/core/platform/share_intent_service.dart';
import 'package:tube_downloader/core/helpers/snackbar_helper.dart';
import 'package:tube_downloader/core/router/app_router.dart';
import 'package:tube_downloader/core/theme/app_theme.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_cubit.dart';
import 'package:tube_downloader/features/settings/logic/appearance_cubit/appearance_state.dart';
import 'package:tube_downloader/l10n/app_localizations.dart';

/// Root widget: themes, locale (and with it RTL), the router.
///
/// The router is created once and kept — rebuilding it on a theme or language
/// change would reset every tab's navigation stack.
class TubeDownloaderApp extends StatefulWidget {
  const TubeDownloaderApp({required this.config, this.router, super.key});

  final AppConfig config;

  /// Tests inject a fresh router per test.
  final GoRouter? router;

  @override
  State<TubeDownloaderApp> createState() => _TubeDownloaderAppState();
}

class _TubeDownloaderAppState extends State<TubeDownloaderApp> {
  late final GoRouter _router = widget.router ?? buildAppRouter();

  @override
  void initState() {
    super.initState();
    // A tapped notification opens its tab (Library / Downloads).
    getIt<NotificationService>().onOpen = _router.go;
    // A link shared from another app (Android) opens New Download with it.
    unawaited(
      getIt<ShareIntentService>().start(
        onShared: () => _router.go(AppRoutes.newDownload),
      ),
    );
  }

  @override
  void dispose() {
    getIt<NotificationService>().onOpen = null;
    if (widget.router == null) _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // .value: the cubit is an app-wide singleton owned by DI, not by this tree.
    return BlocProvider<AppearanceCubit>.value(
      value: getIt<AppearanceCubit>(),
      child: BlocBuilder<AppearanceCubit, AppearanceState>(
        builder: (context, appearance) => MaterialApp.router(
          title: widget.config.appName,
          debugShowCheckedModeBanner: false,
          routerConfig: _router,
          scaffoldMessengerKey: rootScaffoldMessengerKey,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: appearance.themeMode,
          locale: appearance.locale,
          supportedLocales: AppLocalizations.supportedLocales,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
        ),
      ),
    );
  }
}
