import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tube_downloader/core/download_core/domain/repos/activity_assertion.dart';

/// [ActivityAssertion] over the Runner's `com.tubedownloader.app/activity`
/// channel (MainFlutterWindow.swift). macOS only; elsewhere a no-op.
class MethodChannelActivityAssertion implements ActivityAssertion {
  MethodChannelActivityAssertion({bool? enabled})
    : _enabled = enabled ?? Platform.isMacOS;

  static const _channel = MethodChannel('com.tubedownloader.app/activity');
  final bool _enabled;

  @override
  Future<void> begin() => _call('begin', {'reason': 'Downloading videos'});

  @override
  Future<void> end() => _call('end');

  Future<void> _call(String method, [Map<String, Object?>? args]) async {
    if (!_enabled) return;
    // Best effort: a missing hint only lets macOS throttle a background
    // window; it must never fail a download or the queue's dispose.
    try {
      await _channel.invokeMethod<void>(method, args);
    } on MissingPluginException {
      // A host without the channel (tests, an older Runner): nothing to do.
    } on Object catch (e) {
      debugPrint('ActivityAssertion.$method failed: $e');
    }
  }
}
