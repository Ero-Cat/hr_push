
import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../l10n/app_localizations.dart';

import '../heart_rate_manager.dart';
import '../theme/design_system.dart';

class NearbyList extends StatelessWidget {
  const NearbyList({super.key, required this.mgr});

  final HeartRateManager mgr;

  bool _scanEnabled() {
    return mgr.canToggleConnection &&
        !mgr.uiScanning &&
        !mgr.isConnecting &&
        !mgr.isAutoReconnecting &&
        mgr.connectionState != BluetoothConnectionState.connected &&
        mgr.adapterState == BluetoothAdapterState.on;
  }

  @override
  Widget build(BuildContext context) {
    if (mgr.adapterState != BluetoothAdapterState.on) {
       // Optional: Show empty state or hint if Bluetooth is off, 
       // but typically the HeroCard handles the primary state notice.
       // We'll keep it simple for the list.
       return const SizedBox.shrink();
    }

    final l10n = AppLocalizations.of(context)!;
    final devices = mgr.nearbyDevices.take(5).toList();
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(AppSpacing.s20, 0, AppSpacing.s20, AppSpacing.s8),
      child: Row(
        children: [
          Text(
            l10n.nearbyDevices,
            style: AppTypography.caption.copyWith(
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
          const Spacer(),
          if (mgr.uiScanning)
            const CupertinoActivityIndicator(radius: 8)
          else if (_scanEnabled())
            CupertinoButton(
              padding: EdgeInsets.zero,
              minimumSize: Size.zero,
              onPressed: mgr.restartScan,
              child: Text(
                l10n.scan,
                style: AppTypography.caption.copyWith(
                  color: AppColors.accent.resolveFrom(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );

    if (devices.isEmpty) {
      if (mgr.uiScanning) {
        // Scanning but empty
        return Column(
          children: [
            header,
            _EmptyStateTile(text: l10n.searching),
          ],
        );
      } else {
        // Idle and empty
        return Column(
          children: [
            header,
             _EmptyStateTile(text: l10n.noDevicesFound),
          ],
        );
      }
    }

    return Column(
      children: [
        header,
        Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.r12),
            boxShadow: [ AppShadows.card ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.r12),
            child: Container(
              color: AppColors.bgSecondary.resolveFrom(context),
              child: Column(
                children: [
                  for (var i = 0; i < devices.length; i++) ...[
                    if (i > 0)
                       Container(
                         height: 0.5, 
                         margin: const EdgeInsetsDirectional.only(start: 56), 
                         color: AppColors.separator.resolveFrom(context)
                       ),
                    _DeviceTile(
                      device: devices[i],
                      mgr: mgr,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}


class _DeviceTile extends StatelessWidget {
  const _DeviceTile({required this.device, required this.mgr});

  final NearbyDevice device;
  final HeartRateManager mgr;

  // Helper for signal icon (doesn't need localization)
  IconData _signalIcon(int rssi) {
     if (rssi >= -60) return CupertinoIcons.wifi;
     if (rssi >= -80) return CupertinoIcons.wifi_exclamationmark;
     return CupertinoIcons.wifi_slash;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isConnected = mgr.activeDeviceId == device.id && 
        mgr.connectionState == BluetoothConnectionState.connected;
    final isConnecting = mgr.activeDeviceId == device.id &&
        (mgr.isConnecting || mgr.isAutoReconnecting);
    
    final displayName = device.name.isNotEmpty 
        ? device.name 
        : '${l10n.unknownDevice} (${device.id.substring(device.id.length - 4)})';

    // Localized signal text
    String signalText;
    if (device.rssi >= -60) {
      signalText = l10n.signalStrong;
    } else if (device.rssi >= -80) {
      signalText = l10n.signalMedium;
    } else {
      signalText = l10n.signalWeak;
    }

    return CupertinoButton(
       padding: EdgeInsets.zero,
       color: AppColors.bgSecondary.resolveFrom(context),
       onPressed: () async {
         if (mgr.isConnecting || mgr.isAutoReconnecting) return;
         await mgr.manualConnect(device);
       },
       child: Padding(
         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18), // Breathable padding
         child: Row(
           children: [
             // Leading Icon with soft background
             Container(
               width: 44,
               height: 44,
               decoration: BoxDecoration(
                 color: AppColors.accent.resolveFrom(context).withValues(alpha: 0.1),
                 shape: BoxShape.circle,
               ),
               alignment: Alignment.center,
               child: Icon(
                 CupertinoIcons.heart_fill,
                 color: AppColors.accent.resolveFrom(context),
                 size: 24,
               ),
             ),
             const SizedBox(width: 16),
             
             // Content
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Text(
                     displayName,
                     style: AppTypography.body.copyWith(
                       color: AppColors.textPrimary.resolveFrom(context),
                       fontWeight: FontWeight.w600,
                     ),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                   ),
                   const SizedBox(height: 2),
                   Row(
                     children: [
                       Icon(_signalIcon(device.rssi), size: 12, color: AppColors.textTertiary.resolveFrom(context)),
                       const SizedBox(width: 4),
                       Text(
                         '$signalText (${device.rssi} dBm)',
                         style: AppTypography.caption.copyWith(
                           color: AppColors.textSecondary.resolveFrom(context),
                         ),
                       ),
                     ],
                   ),
                 ],
               ),
             ),
             const SizedBox(width: 12),
             
             // Action
             if (isConnecting)
               const CupertinoActivityIndicator()
             else if (isConnected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.resolveFrom(context).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.resolveFrom(context).withValues(alpha: 0.2)),
                  ),
                  child: Text(
                    l10n.deviceOnline,
                    style: AppTypography.caption.copyWith(
                      color: AppColors.success.resolveFrom(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
             else
               Icon(
                 CupertinoIcons.chevron_right,
                 color: AppColors.textTertiary.resolveFrom(context),
                 size: 20,
               ),
           ],
         ),
       ),
    );
  }
}

class _EmptyStateTile extends StatelessWidget {
  const _EmptyStateTile({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.bgSecondary.resolveFrom(context),
        borderRadius: BorderRadius.circular(AppRadius.r12),
      ),
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 20),
      alignment: Alignment.center,
      child: Column(
        children: [
          Icon(CupertinoIcons.search, size: 32, color: AppColors.textTertiary.resolveFrom(context)),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: AppTypography.subheadline.copyWith(
              color: AppColors.textSecondary.resolveFrom(context),
            ),
          ),
        ],
      ),
    );
  }
}
