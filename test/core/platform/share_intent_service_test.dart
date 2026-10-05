import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tube_downloader/core/platform/incoming_links.dart';
import 'package:tube_downloader/core/platform/share_intent_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.tubedownloader.app/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late IncomingLinks links;
  late int opened;

  setUp(() {
    links = IncomingLinks();
    opened = 0;
  });
  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
    return links.dispose();
  });

  /// What MainActivity sends for a later share.
  Future<void> shareFromAndroid(String text) => messenger.handlePlatformMessage(
    channel.name,
    const StandardMethodCodec().encodeMethodCall(MethodCall('shared', text)),
    (_) {},
  );

  test('the share that opened the app, then a later one', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'initialText');
      return 'https://youtu.be/R6MlUcmOul8';
    });
    final service = ShareIntentService(links, enabled: true);
    await service.start(onShared: () => opened++);
    expect(links.takePending(), 'https://youtu.be/R6MlUcmOul8');

    final live = <String>[];
    final sub = links.stream.listen(live.add);
    await shareFromAndroid('Watch https://youtu.be/aqz-KE-bpKQ');
    await pumpEventQueue();
    expect(live, ['Watch https://youtu.be/aqz-KE-bpKQ']);
    expect(opened, 2);
    await sub.cancel();
    service.dispose();
  });

  test('nothing shared, or not Android: nothing happens', () async {
    messenger.setMockMethodCallHandler(channel, (_) async => null);
    await ShareIntentService(
      links,
      enabled: true,
    ).start(onShared: () => opened++);
    await ShareIntentService(
      links,
      enabled: false,
    ).start(onShared: () => opened++);
    expect((links.takePending(), opened), (null, 0));
  });
}
