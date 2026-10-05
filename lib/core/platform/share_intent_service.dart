import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tube_downloader/core/platform/incoming_links.dart';

/// Android's share sheet → [IncomingLinks]: a link shared from YouTube or a
/// browser opens New Download with it. The Runner's
/// `com.tubedownloader.app/share` channel (MainActivity.kt) answers
/// "initialText" (the share that opened the app) and calls "shared" for
/// later ones. iOS gets a share extension in the release phase; desktop has
/// no share target.
class ShareIntentService {
  ShareIntentService(this._links, {bool? enabled})
    : _enabled = enabled ?? Platform.isAndroid;

  final IncomingLinks _links;
  final bool _enabled;
  bool _started = false;

  static const _channel = MethodChannel('com.tubedownloader.app/share');

  /// [onShared] brings New Download to the front.
  Future<void> start({required void Function() onShared}) async {
    if (!_enabled || _started) return;
    _started = true;
    void deliver(String? text) {
      if (text == null || text.trim().isEmpty) return;
      _links.add(text);
      onShared();
    }

    _channel.setMethodCallHandler((call) async {
      if (call.method == 'shared') deliver(call.arguments as String?);
    });
    try {
      deliver(await _channel.invokeMethod<String>('initialText'));
    } on Object catch (e) {
      debugPrint('ShareIntentService: not available (${e.runtimeType})');
    }
  }

  void dispose() => _channel.setMethodCallHandler(null);
}
