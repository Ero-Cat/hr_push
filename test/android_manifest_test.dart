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
}
