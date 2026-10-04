import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/app_bootstrap.dart';
import 'package:tube_downloader/core/configs/app_config.dart';

void main() {
  late DebugPrintCallback original;

  setUp(() => original = debugPrint);
  tearDown(() => debugPrint = original);

  test('production mutes debugPrint and hands back a working console', () {
    final console = installLoggingPolicy(const AppConfig.production());

    expect(identical(debugPrint, original), isFalse);
    expect(identical(console, original), isTrue);
  });

  test('development leaves debugPrint untouched', () {
    installLoggingPolicy(const AppConfig.development());

    expect(identical(debugPrint, original), isTrue);
  });

  test('a second production install never hands back the muted hook', () {
    installLoggingPolicy(const AppConfig.production());
    final muted = debugPrint;

    final console = installLoggingPolicy(const AppConfig.production());

    expect(identical(console, muted), isFalse);
    expect(identical(console, debugPrintThrottled), isTrue);
  });
}
