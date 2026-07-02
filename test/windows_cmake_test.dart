import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Windows build silences MSVC experimental coroutine deprecation', () {
    final cmake = File('windows/CMakeLists.txt').readAsStringSync();

    expect(
      cmake,
      contains('_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS'),
      reason: 'VS 18/MSVC 14.51 fails plugins that include '
          '<experimental/coroutine> unless this compatibility macro is set.',
    );
  });
}
