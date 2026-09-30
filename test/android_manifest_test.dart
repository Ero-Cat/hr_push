import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'Android release manifest declares INTERNET permission for push targets',
    () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('android.permission.INTERNET'),
        reason:
            'Release builds need INTERNET permission for OSC UDP, HTTP, '
            'WebSocket, and MQTT push traffic.',
      );
    },
  );

  test('Android declares the connected-device foreground service', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(manifest, contains('android.permission.FOREGROUND_SERVICE'));
    expect(
      manifest,
      contains('android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE'),
    );
    expect(
      manifest,
      contains('android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'),
    );
    expect(manifest, contains('android:name=".HrForegroundService"'));
    expect(
      manifest,
      contains('android:foregroundServiceType="connectedDevice"'),
    );
  });

  test('Android manifest allows the in-app APK self-update flow', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();

    expect(
      manifest,
      contains('android.permission.REQUEST_INSTALL_PACKAGES'),
      reason:
          'The in-app updater hands the downloaded APK to the system '
          'package installer, which needs this permission.',
    );

    final activity = File(
      'android/app/src/main/kotlin/moe/iacg/hrpush/MainActivity.kt',
    ).readAsStringSync();
    expect(activity, contains('moe.iacg.hrpush/system'));
    expect(activity, contains('getPrimaryAbi'));
  });

  test(
    'Android foreground bridge starts service and opens battery settings',
    () {
      final activity = File(
        'android/app/src/main/kotlin/moe/iacg/hrpush/MainActivity.kt',
      ).readAsStringSync();
      final service = File(
        'android/app/src/main/kotlin/moe/iacg/hrpush/HrForegroundService.kt',
      );

      expect(service.existsSync(), isTrue);
      final serviceSource = service.readAsStringSync();

      expect(activity, contains('startForegroundService'));
      expect(activity, contains('stopForegroundService'));
      expect(activity, contains('openBackgroundRuntimeSettings'));
      expect(activity, contains('isIgnoringBatteryOptimizations'));
      expect(activity, contains('ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS'));
      expect(activity, contains('ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS'));
      expect(activity, contains('ACTION_APPLICATION_DETAILS_SETTINGS'));
      expect(serviceSource, contains('startForeground'));
      expect(
        serviceSource,
        contains('FOREGROUND_SERVICE_TYPE_CONNECTED_DEVICE'),
      );
      expect(serviceSource, contains('START_STICKY'));
    },
  );
}
