import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter_localizations/flutter_localizations.dart';
import 'l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:window_manager/window_manager.dart';

import 'app_log.dart';
import 'heart_rate_manager.dart';
import 'theme/design_system.dart';
import 'pages/heart_dashboard.dart';

bool get _blePluginSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  AppLog.init(enabled: false);

  if (_blePluginSupported) {
    final logLevel = (!kIsWeb && Platform.isAndroid) ? LogLevel.warning : LogLevel.verbose;
    FlutterBluePlus.setLogLevel(logLevel, color: true);
  }

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
      backgroundColor: Color(0x00000000), // Transparent for glass effects if supported
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
          // Wrap with a custom title bar for desktop if needed, 
          // or just generic system UI sync.
          return MediaQuery(
            // Ensure fonts scale appropriately
            data: MediaQuery.of(context).copyWith(textScaler: const TextScaler.linear(1.0)), 
            child: child!,
          );
        },
        home: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(scrollbars: false),
          child: const HeartDashboard(),
        ),
      ),
    );
  }
}
