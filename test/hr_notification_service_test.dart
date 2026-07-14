import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/hr_notification_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('moe.iacg.hrpush/notification');
  final calls = <MethodCall>[];

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'openBackgroundRuntimeSettings') return true;
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('forwards foreground-service lifecycle calls to Android', () async {
    final service = HrNotificationService(isAndroid: () => true);

    expect(await service.start(), isTrue);
    await service.showConnected(deviceName: 'Band', bpm: 72);
    await service.showDisconnected();
    expect(await service.openBackgroundRuntimeSettings(), isTrue);
    await service.stop();

    expect(calls.map((call) => call.method), [
      'startForegroundService',
      'updateNotification',
      'updateNotification',
      'openBackgroundRuntimeSettings',
      'stopForegroundService',
    ]);
    expect(calls[1].arguments, {
      'bpm': 72,
      'deviceName': 'Band',
      'isConnected': true,
    });
    expect(calls[2].arguments, {
      'bpm': 0,
      'deviceName': '',
      'isConnected': false,
    });
  });
}
