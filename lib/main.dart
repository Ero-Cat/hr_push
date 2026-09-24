import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'app_log.dart';
import 'heart_rate_manager.dart';
import 'l10n/l10n_keys.dart';
import 'theme/design_system.dart';
import 'pages/heart_dashboard.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.init(enabled: false);

  // Desktop configuration for a phone-like feel
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    const size = Size(430, 800);
    final options = const WindowOptions(
      size: size,
      minimumSize: size,
      // maximumSize: size, // Allow resizing if desired, but keep it phone-like default
      center: true,
      title: 'Heart Rate',
      backgroundColor: Color(
        0x00000000,
      ), // Transparent for glass effects if supported
      titleBarStyle: TitleBarStyle.hidden,
    );

    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.setHasShadow(true);
      await windowManager.show();
      await windowManager.focus();
    });
  }

  // Set system UI style (transparent status bar for edge-to-edge)
  if (Platform.isAndroid) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Color(0x00000000),
        systemNavigationBarColor: Color(0x00000000),
        systemNavigationBarDividerColor: Color(0x00000000),
      ),
    );
  }

  runApp(const HrOscApp());
}

class HrOscApp extends StatelessWidget {
  const HrOscApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HeartRateManager()..start(),
      child: CupertinoApp(
        debugShowCheckedModeBanner: false,
        title: 'Heart Rate',
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        theme: CupertinoThemeData(
          primaryColor: AppColors.accent,
          scaffoldBackgroundColor: AppColors.bgPrimary,
          barBackgroundColor: AppColors.bgSecondary,
          textTheme: CupertinoTextThemeData(
            // Apply SF Display/Text font family if available
            textStyle: AppTypography.body,
            navTitleTextStyle: AppTypography.headline,
            navLargeTitleTextStyle: AppTypography.largeTitle,
          ),
        ),
        builder: (context, child) {
          // Feed the manager a localizer so platform notifications can
          // render status text in the active app locale.
          final l10n = AppLocalizations.of(context);
          if (l10n != null) {
            HeartRateManager.statusLocalizer = (key, param) =>
                localizedStatus(l10n, key, param);
          }
          return child!;
        },
        home: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: const HeartDashboard(),
        ),
      ),
    );
  }
}
