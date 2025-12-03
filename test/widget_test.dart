// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:hr_push/main.dart';

void main() {
  testWidgets('Dashboard renders basic UI', (WidgetTester tester) async {
    await tester.pumpWidget(const HrOscApp());

    expect(find.text('HR PUSH'), findsOneWidget);
    expect(find.text('附近心率设备'), findsOneWidget);
    expect(find.textContaining('扫描'), findsOneWidget);

    // No heart rate yet, so placeholder should be shown.
    expect(find.text('--'), findsOneWidget);
  });
}
