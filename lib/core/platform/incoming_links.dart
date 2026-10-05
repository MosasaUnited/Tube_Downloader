import 'dart:async';

/// Links that arrive from outside the app (Android's share sheet) and wait
/// for the New Download screen to take them — it may not exist yet when the
/// app is opened by a share.
class IncomingLinks {
  final _controller = StreamController<String>.broadcast();
  String? _pending;

  /// Live deliveries while New Download is open.
  Stream<String> get stream => _controller.stream;

  void add(String text) {
    if (text.trim().isEmpty) return;
    if (_controller.hasListener) {
      _controller.add(text);
    } else {
      _pending = text;
    }
  }

  /// The link that arrived before anyone listened (taken once).
  String? takePending() {
    final text = _pending;
    _pending = null;
    return text;
  }

  Future<void> dispose() => _controller.close();
}
