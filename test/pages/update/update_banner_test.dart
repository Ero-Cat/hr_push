import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr_push/l10n/app_localizations.dart';
import 'package:hr_push/pages/update/update_banner.dart';
import 'package:hr_push/services/update_service.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  Future<UpdateService> seedAvailableUpdate() async {
    final svc = UpdateService(
      client: MockClient(
        (request) async => http.Response(
          jsonEncode({
            'tag_name': 'v999.0.0',
            'body': '- Fix reconnect',
            'html_url':
                'https://github.com/Ero-Cat/hr_push/releases/tag/v999.0.0',
            'assets': [
              {
                'name': 'app-release-v999.0.0.apk',
                'browser_download_url': 'https://example.com/x.apk',
              },
            ],
          }),
          200,
        ),
      ),
    );
    await svc.checkForUpdates(manual: true);
    return svc;
  }

  Future<void> pumpBanner(WidgetTester tester, UpdateService svc) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<UpdateService>.value(
        value: svc,
        child: CupertinoApp(
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const CupertinoPageScaffold(child: UpdateBanner()),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('banner appears when a newer release is known', (tester) async {
    final svc = await seedAvailableUpdate();
    await pumpBanner(tester, svc);

    expect(find.text('New version available v999.0.0'), findsOneWidget);
    expect(find.text('Update Now'), findsOneWidget);
  });

  testWidgets('banner hides after the version is skipped', (tester) async {
    final svc = await seedAvailableUpdate();
    await pumpBanner(tester, svc);
    expect(find.text('New version available v999.0.0'), findsOneWidget);

    svc.ignoreCurrentVersion();
    await tester.pumpAndSettle();

    expect(find.text('New version available v999.0.0'), findsNothing);
  });
}
