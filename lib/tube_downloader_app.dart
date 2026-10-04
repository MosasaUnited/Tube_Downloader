import 'package:flutter/material.dart';
import 'package:tube_downloader/core/configs/app_config.dart';

/// Root widget. Phase 0 placeholder: Phase 1 replaces the home with
/// `MaterialApp.router` (themes, locale and the adaptive shell).
class TubeDownloaderApp extends StatelessWidget {
  const TubeDownloaderApp({required this.config, super.key});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: config.appName,
      debugShowCheckedModeBanner: false,
      home: const Scaffold(body: Center(child: FlutterLogo(size: 96))),
    );
  }
}
