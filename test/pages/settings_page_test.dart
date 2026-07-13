import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/l10n/app_localizations.dart';
import 'package:hr_push/models/models.dart';
import 'package:hr_push/pages/settings_page.dart';

void main() {
  testWidgets('configures VRChat heartbeat outputs and normalizes duration', (
    tester,
  ) async {
    HeartRateSettings? saved;

    await tester.pumpWidget(
      CupertinoApp(
        locale: const Locale('zh'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
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
      ),
    );

    await tester.tap(find.text('open-settings'));
    await tester.pumpAndSettle();

    for (final label in [
      '接收地址',
      '在线状态地址',
      '实时心率地址',
      '心率比例地址',
      '整数闪烁',
      '布尔闪烁',
      '逐拍翻转',
      '闪烁时长 (ms)',
      '最大心率',
    ]) {
      expect(find.text(label), findsOneWidget);
    }
    expect(find.textContaining('参数'), findsNothing);

    final intOutputRow = find.ancestor(
      of: find.text('整数闪烁'),
      matching: find.byType(CupertinoFormRow),
    );
    await tester.tap(
      find.descendant(of: intOutputRow, matching: find.byType(CupertinoSwitch)),
    );
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

    await tester.tap(find.text('保存'));
    await tester.pumpAndSettle();

    expect(saved, isNotNull);
    expect(saved!.oscHeartbeatIntEnabled, isFalse);
    expect(saved!.oscHeartbeatPulseEnabled, isTrue);
    expect(saved!.oscHeartbeatToggleEnabled, isTrue);
    expect(saved!.oscHeartbeatPulseDurationMs, 120);
  });
}
