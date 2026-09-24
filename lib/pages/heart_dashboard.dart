import 'dart:io';
import '../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../heart_rate_manager.dart';
import '../models/models.dart';
import '../theme/design_system.dart';
import '../widgets/hero_card.dart';
import '../widgets/nearby_list.dart';
import 'settings_page.dart';

class HeartDashboard extends StatefulWidget {
  const HeartDashboard({super.key});

  @override
  State<HeartDashboard> createState() => _HeartDashboardState();
}

class _HeartDashboardState extends State<HeartDashboard> {
  HeartRateManager? _manager;
  bool _guideShowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final mgr = context.read<HeartRateManager>();
      _manager = mgr;
      mgr.addListener(_onManagerUpdate);
      _onManagerUpdate();
    });
  }

  @override
  void dispose() {
    _manager?.removeListener(_onManagerUpdate);
    super.dispose();
  }

  void _onManagerUpdate() {
    final mgr = _manager;
    if (mgr == null || !mounted) return;
    if (mgr.xiaomiGuidePending && !_guideShowing) {
      _guideShowing = true;
      _showXiaomiGuide(mgr);
    }
  }

  /// Guidance for Xiaomi/Redmi wearables that connect but never expose the
  /// standard heart rate service: they need "Heart Rate Broadcast" enabled
  /// on the watch first.
  void _showXiaomiGuide(HeartRateManager mgr) {
    final l10n = AppLocalizations.of(context)!;
    final result = showCupertinoDialog<String>(
      context: context,
      barrierDismissible: true,
      builder: (dialogContext) => CupertinoAlertDialog(
        title: Text(l10n.xiaomiGuideTitle),
        content: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(l10n.xiaomiGuideBody),
        ),
        actions: [
          CupertinoDialogAction(
            onPressed: () => Navigator.of(dialogContext).pop('rescan'),
            child: Text(l10n.xiaomiGuideRescan),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.xiaomiGuideGotIt),
          ),
        ],
      ),
    );
    result.then((action) {
      _guideShowing = false;
      mgr.dismissXiaomiGuide();
      if (action == 'rescan') {
        mgr.restartScan();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    // Check if we are on Windows to show custom controls
    final isWindows = !kIsWeb && Platform.isWindows;
    final l10n = AppLocalizations.of(context)!;

    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgPrimary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
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
        builder: (_) => SettingsPage(initial: mgr.settings, manager: mgr),
      ),
    );
    if (updated != null) {
      await mgr.updateSettings(updated);
    }
  }
}
