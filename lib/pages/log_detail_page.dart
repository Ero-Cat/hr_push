
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme, ThemeData, TextTheme;
import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:loggy/loggy.dart' as loggy;
import '../l10n/app_localizations.dart';
import '../app_log.dart';
import '../theme/design_system.dart';

class LogDetailPage extends StatefulWidget {
  const LogDetailPage({super.key});

  @override
  State<LogDetailPage> createState() => _LogDetailPageState();
}

class _LogDetailPageState extends State<LogDetailPage> {
  loggy.LogLevel _level = loggy.LogLevel.all;

  @override
  Widget build(BuildContext context) {
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgPrimary,
      navigationBar: CupertinoNavigationBar(
        middle: Text(l10n.logsTitle),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () {
            AppLog.clear();
            setState(() {});
          },
          child: Text(l10n.btnClear),
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 12),
            CupertinoSegmentedControl<loggy.LogLevel>(
              groupValue: _level,
              onValueChanged: (v) => setState(() => _level = v),
              children: {
                loggy.LogLevel.all: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(l10n.filterAll)),
                loggy.LogLevel.info: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(l10n.filterInfo)),
                loggy.LogLevel.error: Padding(padding: const EdgeInsets.symmetric(horizontal: 10), child: Text(l10n.filterError)),
              },
            ),
            const SizedBox(height: 12),
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.bgSecondary.resolveFrom(context),
                  border: Border.all(color: AppColors.separator.resolveFrom(context)),
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadius.r12),
                  child: Theme(
                    data: ThemeData(
                      brightness: isDark ? Brightness.dark : Brightness.light,
                      textTheme: const TextTheme(
                        bodyMedium: TextStyle(fontFamily: 'Courier', fontSize: 12),
                      ),
                    ),
                    child: LoggyStreamWidget(logLevel: _level),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
