import 'dart:io';
import '../l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import '../heart_rate_manager.dart';
import '../models/models.dart';
import '../services/push_coordinator.dart';
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
                  const SizedBox(height: AppSpacing.s12),
                  const _OscStatusStrip(),
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
      CupertinoPageRoute(builder: (_) => SettingsPage(initial: mgr.settings)),
    );
    if (updated != null) {
      await mgr.updateSettings(updated);
    }
  }
}

class _OscStatusStrip extends StatelessWidget {
  const _OscStatusStrip();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = context.watch<HeartRateManager>().oscStatus;
    final color = _statusColor(status.state).resolveFrom(context);
    final label = _statusLabel(l10n, status.state);
    final detail = status.target.isEmpty ? label : status.target;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.s16,
        vertical: AppSpacing.s12,
      ),
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: AppColors.separator
              .resolveFrom(context)
              .withValues(alpha: 0.5),
          width: 0.5,
        ),
      ),
      child: Row(
        children: [
          Icon(
            CupertinoIcons.dot_radiowaves_left_right,
            size: 18,
            color: color,
          ),
          const SizedBox(width: AppSpacing.s12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.oscStatusTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.caption.copyWith(
                    color: AppColors.textTertiary.resolveFrom(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.s4),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.subheadline.copyWith(
                    color: AppColors.textPrimary.resolveFrom(context),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.s12),
          Container(
            constraints: const BoxConstraints(maxWidth: 104),
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: AppSpacing.s8),
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.caption.copyWith(
                      color: color,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  CupertinoDynamicColor _statusColor(OscSendState state) {
    switch (state) {
      case OscSendState.disabled:
        return AppColors.textTertiary;
      case OscSendState.ready:
        return AppColors.warning;
      case OscSendState.sent:
        return AppColors.success;
      case OscSendState.acknowledged:
        return AppColors.success;
      case OscSendState.error:
        return AppColors.danger;
    }
  }

  String _statusLabel(AppLocalizations l10n, OscSendState state) {
    switch (state) {
      case OscSendState.disabled:
        return l10n.oscStatusDisabled;
      case OscSendState.ready:
        return l10n.oscStatusReady;
      case OscSendState.sent:
        return l10n.oscStatusSent;
      case OscSendState.acknowledged:
        return l10n.oscStatusAcknowledged;
      case OscSendState.error:
        return l10n.oscStatusError;
    }
  }
}
