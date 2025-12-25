

import 'dart:io';
import '../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../heart_rate_manager.dart';
import '../theme/design_system.dart';
import '../widgets/hero_card.dart';
import '../widgets/nearby_list.dart';
import 'settings_page.dart';

class HeartDashboard extends StatelessWidget {
  const HeartDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    // Check if we are on Windows to show custom controls
    final isWindows = !kIsWeb && Platform.isWindows;
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgPrimary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: DragToMoveArea(
              child: Text(
                 l10n.appTitle, 
                 style: const TextStyle(fontFamily: '.SF Pro Display'),
              ),
            ),
            backgroundColor: AppColors.bgSecondary,
            border: null, // Clean look without hairline
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => _openSettings(context),
                  child: const Icon(CupertinoIcons.gear_alt_fill),
                ),
                if (isWindows) ...[
                  const SizedBox(width: 16),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => windowManager.minimize(),
                    child: const Icon(CupertinoIcons.minus, size: 20),
                  ),
                  const SizedBox(width: 8),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () => windowManager.close(),
                    child: const Icon(CupertinoIcons.xmark, size: 20),
                  ),
                ],
              ],
            ),
          ),
          CupertinoSliverRefreshControl(
            onRefresh: () async {
              final mgr = context.read<HeartRateManager>();
              mgr.restartScan();
              // Await a short delay to let the UI show the refresh action
              await Future.delayed(const Duration(milliseconds: 600));
            },
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.all(AppSpacing.screenPadding),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  const SizedBox(height: AppSpacing.s8),
                  const HeroCard(),
                  const SizedBox(height: AppSpacing.s32),
                  Consumer<HeartRateManager>(
                    builder: (context, mgr, _) => NearbyList(mgr: mgr),
                  ),
                  const SizedBox(height: 100), // Bottom padding
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }


  Future<void> _openSettings(BuildContext context) async {
    final mgr = context.read<HeartRateManager>();
    final updated = await Navigator.of(context).push<HeartRateSettings>(
      CupertinoPageRoute(
        builder: (_) => SettingsPage(initial: mgr.settings),
      ),
    );
    if (updated != null) {
      await mgr.updateSettings(updated);
    }
  }
}
