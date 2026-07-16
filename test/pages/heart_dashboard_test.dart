import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('dashboard source omits the OSC delivery status strip', () {
    final source = File('lib/pages/heart_dashboard.dart').readAsStringSync();

    expect(source, isNot(contains('_OscStatusStrip')));
    expect(source, isNot(contains('oscStatusTitle')));
  });
}
