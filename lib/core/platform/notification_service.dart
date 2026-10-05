import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

/// System notifications (Settings › Notifications). Best effort: a platform
/// that refuses only means no banner — downloads never depend on it.
class NotificationService {
  NotificationService({FlutterLocalNotificationsPlugin? plugin})
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _plugin;
  bool _ready = false;

  /// Called with the tapped notification's route (the app points it at its
  /// router).
  void Function(String route)? onOpen;

  static const _darwin = DarwinInitializationSettings(
    // Asked when it matters (enabling the setting, the first finished
    // download), not at launch.
    requestAlertPermission: false,
    requestBadgePermission: false,
    requestSoundPermission: false,
  );

  Future<void> init() async {
    if (_ready) return;
    try {
      await _plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: _darwin,
          macOS: _darwin,
          windows: WindowsInitializationSettings(
            appName: 'Tube Downloader',
            appUserModelId: 'TubeDownloader.App',
            guid: '55a25e0b-81af-4068-bc4f-23785251d7ce',
          ),
        ),
        onDidReceiveNotificationResponse: (response) {
          final route = response.payload;
          if (route != null) onOpen?.call(route);
        },
      );
      _ready = true;
    } on Object catch (e) {
      debugPrint('NotificationService: not available (${e.runtimeType})');
    }
  }

  /// Asks the system once (it remembers the answer); true when allowed.
  Future<bool> ensurePermission() async {
    await init();
    if (!_ready) return false;
    try {
      if (Platform.isAndroid) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin
                >()
                ?.requestNotificationsPermission() ??
            false;
      }
      if (Platform.isIOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  IOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      }
      if (Platform.isMacOS) {
        return await _plugin
                .resolvePlatformSpecificImplementation<
                  MacOSFlutterLocalNotificationsPlugin
                >()
                ?.requestPermissions(alert: true, sound: true) ??
            false;
      }
      return true; // Windows: no prompt.
    } on Object catch (e) {
      debugPrint('NotificationService: permission ${e.runtimeType}');
      return false;
    }
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    required String route,
  }) async {
    if (!_ready) return;
    try {
      await _plugin.show(
        id: id,
        title: title,
        body: body,
        payload: route,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'downloads',
            'Downloads',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    } on Object catch (e) {
      debugPrint('NotificationService: show ${e.runtimeType}');
    }
  }
}
