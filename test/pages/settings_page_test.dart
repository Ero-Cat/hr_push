import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/l10n/app_localizations.dart';
import 'package:hr_push/models/models.dart';
import 'package:hr_push/pages/settings_page.dart';

void main() {
  Future<void> pumpApp(WidgetTester tester, Widget home) async {
    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: home,
      ),
    );
  }

  testWidgets('configures heartbeat outputs and normalizes duration', (
    tester,
  ) async {
    HeartRateSettings? saved;

    await pumpApp(
      tester,
      Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<HeartRateSettings>(
                  CupertinoPageRoute(
                    builder: (_) =>
                        SettingsPage(initial: HeartRateSettings.defaults()),
                  ),
                );
              },
              child: const Text('open-settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-settings'));
    await tester.pumpAndSettle();

    // Basic fields of the visible (top) sections.
    expect(find.text('接收地址'), findsOneWidget);
    expect(find.text('推送地址'), findsOneWidget);

    // Advanced OSC fields start collapsed.
    expect(find.text('在线状态地址'), findsNothing);
    await tester.tap(find.text('显示高级设置'));
    await tester.pumpAndSettle();
    expect(find.text('在线状态地址'), findsOneWidget);
    expect(find.text('实时心率地址'), findsOneWidget);
    expect(find.text('心率比例地址'), findsOneWidget);

    final intSwitch = find
        .descendant(
          of: find.ancestor(
            of: find.text('整数闪烁'),
            matching: find.byType(CupertinoFormRow),
          ),
          matching: find.byType(CupertinoSwitch),
        )
        .first;
    await tester.ensureVisible(intSwitch);
    await tester.pumpAndSettle();
    await tester.tap(intSwitch);
    await tester.pump();

    expect(find.text('/avatar/parameters/HeartBeatInt'), findsNothing);
    expect(find.text('/avatar/parameters/HeartBeatPulse'), findsOneWidget);
    expect(find.text('/avatar/parameters/HeartBeatToggle'), findsOneWidget);

    final durationRow = find.ancestor(
      of: find.text('闪烁时长 (ms)'),
      matching: find.byType(CupertinoFormRow),
    );
    final durationInput = find.descendant(
      of: durationRow,
      matching: find.byType(CupertinoTextField),
    );
    await tester.ensureVisible(durationInput);
    await tester.enterText(durationInput, '5000');
    await tester.pump();

    // Invalid duration keeps the page open with an inline error.
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));
    expect(saved, isNull);
    expect(find.text('闪烁时长需在 20-1000 ms 之间'), findsOneWidget);

    await tester.enterText(durationInput, '500');
    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(saved, isNotNull);
    expect(saved!.oscHeartbeatIntEnabled, isFalse);
    expect(saved!.oscHeartbeatPulseEnabled, isTrue);
    expect(saved!.oscHeartbeatToggleEnabled, isTrue);
    expect(saved!.oscHeartbeatPulseDurationMs, 500);
  });

  testWidgets('blocks save on an invalid endpoint URL', (tester) async {
    HeartRateSettings? saved;

    await pumpApp(
      tester,
      Builder(
        builder: (context) => CupertinoPageScaffold(
          child: Center(
            child: CupertinoButton(
              onPressed: () async {
                saved = await Navigator.of(context).push<HeartRateSettings>(
                  CupertinoPageRoute(
                    builder: (_) =>
                        SettingsPage(initial: HeartRateSettings.defaults()),
                  ),
                );
              },
              child: const Text('open-settings'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open-settings'));
    await tester.pumpAndSettle();

    final endpointRow = find.ancestor(
      of: find.text('推送地址'),
      matching: find.byType(CupertinoFormRow),
    );
    await tester.enterText(
      find.descendant(
        of: endpointRow,
        matching: find.byType(CupertinoTextField),
      ),
      'not-a-url',
    );
    await tester.pump();

    await tester.tap(find.text('保存'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 2));

    expect(saved, isNull);
    expect(find.text('请输入有效的 http/https/ws/wss 地址'), findsOneWidget);
  });
}
