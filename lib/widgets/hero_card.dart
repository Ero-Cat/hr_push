
import '../l10n/app_localizations.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';

import '../heart_rate_manager.dart';
import '../theme/design_system.dart';
import 'glass_surface.dart';

class HeroCard extends StatelessWidget {
  const HeroCard({super.key});

  // Extracted logic to keep presentation clean
  bool _toggleEnabled(HeartRateManager mgr) {
    return mgr.canToggleConnection &&
        (!mgr.isConnecting ||
            mgr.connectionState == BluetoothConnectionState.connected);
  }

  String _toggleLabel(BuildContext context, HeartRateManager mgr) {
    final l10n = AppLocalizations.of(context)!;
    if (mgr.connectionState == BluetoothConnectionState.connected) {
      return l10n.disconnect;
    }
    if (mgr.isConnecting) return l10n.connecting;
    if (mgr.isAutoReconnecting) return l10n.autoReconnecting;
    return l10n.connectDevice;
  }

  Color _statusColor(HeartRateManager mgr) {
    if (mgr.connectionState == BluetoothConnectionState.connected) {
      return AppColors.success;
    }
    if (mgr.isConnecting || mgr.isAutoReconnecting) {
      return AppColors.warning;
    }
    return AppColors.textTertiary;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final mgr = context.watch<HeartRateManager>();
    
    final bpm = mgr.heartRate;
    final deviceName = mgr.connectedName.isEmpty ? l10n.noDeviceConnected : mgr.connectedName;
    final isConnected = mgr.connectionState == BluetoothConnectionState.connected;
    
    // Status color logic (inline for brevity or kept in helper)
    final statusColor = CupertinoDynamicColor.resolve(_statusColor(mgr), context);

    return GlassSurface(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // 1. Heart Animation (Centered)
          Center(child: _AnimatedHeart(bpm: bpm)),
          const SizedBox(height: 24),
          
          // 2. BPM Display (Massive)
          Column(
            children: [
              Text(
                bpm != null ? '$bpm' : '--',
                textAlign: TextAlign.center,
                style: AppTypography.largeTitle.copyWith(
                  fontSize: 72,
                  fontWeight: FontWeight.w700, // New refined weight
                  height: 1.0,
                  color: AppColors.textPrimary.resolveFrom(context),
                  letterSpacing: -1.5,
                ),
              ),
              Text(
                l10n.bpmUnit,
                style: AppTypography.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textTertiary.resolveFrom(context),
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 32),

          // 3. Status Pill (Device + State)
          Container(
             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
             decoration: BoxDecoration(
               color: AppColors.bgSecondary.resolveFrom(context).withValues(alpha: 0.5),
               borderRadius: BorderRadius.circular(16),
               border: Border.all(
                 color: AppColors.separator.resolveFrom(context).withValues(alpha: 0.5),
                 width: 0.5,
               ),
             ),
             child: Row(
               mainAxisSize: MainAxisSize.min,
               children: [
                 // Status Dot
                 Container(
                   width: 8,
                   height: 8,
                   decoration: BoxDecoration(
                     color: statusColor,
                     shape: BoxShape.circle,
                     boxShadow: [
                       BoxShadow(
                         color: statusColor.withValues(alpha: 0.4),
                         blurRadius: 4,
                         spreadRadius: 1,
                       )
                     ],
                   ),
                 ),
                 const SizedBox(width: 8),
                 Flexible(
                   child: Text(
                     isConnected ? deviceName : (mgr.isConnecting ? l10n.connecting : l10n.disconnect),
                     maxLines: 1,
                     overflow: TextOverflow.ellipsis,
                     style: AppTypography.caption.copyWith(
                       color: AppColors.textSecondary.resolveFrom(context),
                       fontWeight: FontWeight.w500,
                     ),
                   ),
                 ),
                 if (isConnected && mgr.rssi != null) ...[
                   const SizedBox(width: 8),
                   Container(width: 1, height: 10, color: AppColors.separator.resolveFrom(context)),
                   const SizedBox(width: 8),
                   Icon(CupertinoIcons.wifi, size: 12, color: AppColors.textTertiary.resolveFrom(context)),
                   const SizedBox(width: 4),
                   Text(
                     '${mgr.rssi}',
                     style: AppTypography.caption.copyWith(
                       color: AppColors.textSecondary.resolveFrom(context),
                       fontSize: 10,
                     ),
                   ),
                 ],
               ],
             ),
          ),

          const SizedBox(height: 32),
          
          // 4. Action Button (Wide / Centered)
          SizedBox(
            width: double.infinity,
            child: CupertinoButton(
              padding: const EdgeInsets.symmetric(vertical: 14),
              color: AppColors.accent.resolveFrom(context),
              borderRadius: BorderRadius.circular(24),
              pressedOpacity: 0.8,
              onPressed: _toggleEnabled(mgr)
                  ? () => mgr.toggleConnection()
                  : null,
              child: Text(
                _toggleLabel(context, mgr),
                style: AppTypography.body.copyWith(
                  color: CupertinoColors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}



class _AnimatedHeart extends StatefulWidget {
  const _AnimatedHeart({required this.bpm});
  final int? bpm;

  @override
  State<_AnimatedHeart> createState() => _AnimatedHeartState();
}

class _AnimatedHeartState extends State<_AnimatedHeart> with TickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _scale;
  late Animation<double> _opacity;
  
  // For the ripple effect
  late AnimationController _rippleCtrl;
  late Animation<double> _rippleScale;
  late Animation<double> _rippleOpacity;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    // Organic "Lub-Dub" Heartbeat Curve
    // 0.0 -> 0.15: Expansion 1 (Lub)
    // 0.15 -> 0.30: Contraction 1
    // 0.30 -> 0.45: Expansion 2 (Dub)
    // 0.45 -> 0.60: Contraction 2
    // 0.60 -> 1.00: Rest
    _scale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.25).chain(CurveTween(curve: Curves.easeOut)), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 1.25, end: 1.0).chain(CurveTween(curve: Curves.easeIn)), weight: 15),
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 40),
    ]).animate(_ctrl);
    
    // Opacity pulse for the inner glow
    _opacity = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.5), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.5, end: 0.2), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.2, end: 0.6), weight: 15),
      TweenSequenceItem(tween: Tween(begin: 0.6, end: 0.2), weight: 15),
      TweenSequenceItem(tween: ConstantTween(0.2), weight: 40),
    ]).animate(_ctrl);

    // Ripple Animation
    _rippleCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    
    _rippleScale = Tween<double>(begin: 1.0, end: 2.5).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );
    
    _rippleOpacity = Tween<double>(begin: 0.4, end: 0.0).animate(
      CurvedAnimation(parent: _rippleCtrl, curve: Curves.easeOut),
    );

    _update();
  }

  @override
  void didUpdateWidget(covariant _AnimatedHeart old) {
    super.didUpdateWidget(old);
    if (widget.bpm != old.bpm) {
      _update();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _rippleCtrl.dispose();
    super.dispose();
  }

  void _update() {
    final bpm = widget.bpm;
    if (bpm == null || bpm <= 0) {
      if (_ctrl.isAnimating) _ctrl.stop();
      if (_rippleCtrl.isAnimating) _rippleCtrl.stop();
      _ctrl.value = 0;
      _rippleCtrl.value = 0;
      return;
    }

    // Calculate duration per beat in ms: 60000 / bpm
    // Limit to reasonable animation speeds (40-180 bpm)
    // If it's too fast, we might want to skip the "dub" or simplify, but for now we clamp.
    final clamped = bpm.clamp(40, 180);
    final ms = (60000 / clamped).round();

    _ctrl.duration = Duration(milliseconds: ms);
    _rippleCtrl.duration = Duration(milliseconds: ms);

    if (!_ctrl.isAnimating) {
      _ctrl.repeat();
      _rippleCtrl.repeat(); // Sync with heartbeat
    }
  }

  @override
  Widget build(BuildContext context) {
    final heartColor = AppColors.heart.resolveFrom(context);
    
    return SizedBox(
      width: 120, // Increased size for ripples
      height: 120,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Ripple Effect
          AnimatedBuilder(
            animation: _rippleCtrl,
            builder: (context, child) {
               // Only show ripple if animating
               if (!_rippleCtrl.isAnimating) return const SizedBox();
               return Transform.scale(
                 scale: _rippleScale.value,
                 child: Container(
                   width: 50,
                   height: 50,
                   decoration: BoxDecoration(
                     shape: BoxShape.circle,
                     color: heartColor.withValues(alpha: _rippleOpacity.value),
                   ),
                 ),
               );
            },
          ),
          
          // Main Heart
          AnimatedBuilder(
            animation: _ctrl,
            builder: (context, child) {
              return Transform.scale(
                scale: _scale.value,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        heartColor.withValues(alpha: _opacity.value), // Pulsing inner
                        heartColor.withValues(alpha: 0.1), // Fixed outer
                      ],
                      stops: const [0.6, 1.0],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: heartColor.withValues(alpha: 0.3),
                        blurRadius: 10 * _scale.value, // Shadow breathes
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(
                    CupertinoIcons.heart_fill,
                    color: heartColor, // Solid heart
                    size: 44, // Slightly larger icon
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
