import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:window_manager/window_manager.dart';
import 'package:tray_manager/tray_manager.dart';

import 'heart_rate_manager.dart';

bool get _blePluginSupported {
  if (kIsWeb) return false;
  return Platform.isAndroid ||
      Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isLinux ||
      Platform.isWindows;
}

class AppColors {
  static const bgPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF000000),
  );
  static const bgSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF1C1C1E),
  );
  static const bgTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFFFFFF),
    darkColor: Color(0xFF2C2C2E),
  );
  static const textPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF000000),
    darkColor: Color(0xFFFFFFFF),
  );
  static const textSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0x993C3C43),
    darkColor: Color(0x99EBEBF5),
  );
  static const textTertiary = CupertinoDynamicColor.withBrightness(
    color: Color(0x4D3C3C43),
    darkColor: Color(0x4DEBEBF5),
  );
  static const separator = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFC6C6C8),
    darkColor: Color(0xFF38383A),
  );
  static const fillPrimary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFE5E5EA),
    darkColor: Color(0xFF3A3A3C),
  );
  static const fillSecondary = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFF2F2F7),
    darkColor: Color(0xFF2C2C2E),
  );
  static const accent = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF007AFF),
    darkColor: Color(0xFF0A84FF),
  );
  static const success = CupertinoDynamicColor.withBrightness(
    color: Color(0xFF34C759),
    darkColor: Color(0xFF32D74B),
  );
  static const warning = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF9500),
    darkColor: Color(0xFFFF9F0A),
  );
  static const danger = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF3B30),
    darkColor: Color(0xFFFF453A),
  );
  static const heart = CupertinoDynamicColor.withBrightness(
    color: Color(0xFFFF375F),
    darkColor: Color(0xFFFF453A),
  );
}

class AppTypography {
  static const largeTitle = TextStyle(
    inherit: false,
    fontSize: 34,
    fontWeight: FontWeight.bold,
    height: 1.2,
    letterSpacing: -0.3,
  );
  static const title1 = TextStyle(
    inherit: false,
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
  );
  static const title2 = TextStyle(
    inherit: false,
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 1.27,
  );
  static const headline = TextStyle(
    inherit: false,
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 1.3,
  );
  static const body = TextStyle(
    inherit: false,
    fontSize: 17,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
  static const callout = TextStyle(
    inherit: false,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
  static const subheadline = TextStyle(
    inherit: false,
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.3,
  );
  static const footnote = TextStyle(
    inherit: false,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.25,
  );
  static const caption = TextStyle(
    inherit: false,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.2,
  );
}

class AppSpacing {
  static const s4 = 4.0;
  static const s8 = 8.0;
  static const s12 = 12.0;
  static const s16 = 16.0;
  static const s20 = 20.0;
  static const s24 = 24.0;
  static const s32 = 32.0;
}

class AppRadius {
  static const r10 = 10.0;
  static const r12 = 12.0;
  static const r16 = 16.0;
}

class AppDurations {
  static const fast = Duration(milliseconds: 150);
  static const base = Duration(milliseconds: 200);
  static const slow = Duration(milliseconds: 300);
}

CupertinoThemeData buildTheme() {
  return CupertinoThemeData(
    primaryColor: AppColors.accent,
    scaffoldBackgroundColor: AppColors.bgPrimary,
    barBackgroundColor: AppColors.bgSecondary,
    textTheme: CupertinoTextThemeData(
      textStyle: AppTypography.body.copyWith(color: AppColors.textPrimary),
      navTitleTextStyle: AppTypography.headline.copyWith(
        color: AppColors.textPrimary,
      ),
      navLargeTitleTextStyle: AppTypography.largeTitle.copyWith(
        color: AppColors.textPrimary,
      ),
    ),
  );
}

Color _resolve(BuildContext context, Color color) {
  return CupertinoDynamicColor.resolve(color, context);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && Platform.isAndroid) {
    final brightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    final isDark = brightness == Brightness.dark;
    const lightBg = Color(0xFFFFFFFF);
    const darkBg = Color(0xFF000000);
    final bg = isDark ? darkBg : lightBg;

    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bg,
        systemNavigationBarDividerColor: bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      ),
    );
  }
  if (_blePluginSupported) {
    final logLevel =
        (!kIsWeb && Platform.isAndroid) ? LogLevel.warning : LogLevel.verbose;
    FlutterBluePlus.setLogLevel(logLevel, color: true);
  }

  // Desktop: lock a consistent window size to keep layout consistent.
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    const size = Size(430, 720); // 紧凑桌面尺寸，接近手机竖屏
    final options = const WindowOptions(
      size: size,
      minimumSize: size,
      maximumSize: size,
      center: true,
      title: '心率推送',
      backgroundColor: Color(0xFFF2F2F7),
    );
    windowManager.waitUntilReadyToShow(options, () async {
      await windowManager.show();
      await windowManager.focus();
    });
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
        title: '心率推送',
        theme: buildTheme(),
        builder: (context, child) => SystemUiSync(
          child: child ?? const SizedBox.shrink(),
        ),
        home: const HeartDashboard(),
      ),
    );
  }
}

class SystemUiSync extends StatefulWidget {
  const SystemUiSync({super.key, required this.child});

  final Widget child;

  @override
  State<SystemUiSync> createState() => _SystemUiSyncState();
}

class _SystemUiSyncState extends State<SystemUiSync>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isAndroid) {
      final brightness = MediaQuery.platformBrightnessOf(context);
      final isDark = brightness == Brightness.dark;
      final bg = CupertinoDynamicColor.resolve(
        AppColors.bgPrimary,
        context,
      );

      final style = SystemUiOverlayStyle(
        statusBarColor: bg,
        statusBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
        statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
        systemNavigationBarColor: bg,
        systemNavigationBarDividerColor: bg,
        systemNavigationBarIconBrightness:
            isDark ? Brightness.light : Brightness.dark,
      );

      SystemChrome.setSystemUIOverlayStyle(style);

      return AnnotatedRegion<SystemUiOverlayStyle>(
        value: style,
        child: widget.child,
      );
    }

    return widget.child;
  }
}

class HeartDashboard extends StatelessWidget {
  const HeartDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.bgPrimary,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          CupertinoSliverNavigationBar(
            largeTitle: const Text('心率推送'),
            trailing: const _SettingsButton(),
          ),
          SliverSafeArea(
            top: false,
            sliver: SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  Selector<HeartRateManager, (String, BluetoothAdapterState)>(
                    selector: (_, mgr) => (mgr.status, mgr.adapterState),
                    builder: (context, data, _) {
                      return _StatusBanner(
                        status: data.$1,
                        adapterState: data.$2,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Selector<
                    HeartRateManager,
                    (
                      int?,
                      String,
                      int?,
                      BluetoothConnectionState,
                      bool,
                      bool,
                      DateTime?,
                      int?,
                    )
                  >(
                    selector: (_, mgr) => (
                      mgr.heartRate,
                      mgr.connectedName.isEmpty ? '未连接' : mgr.connectedName,
                      mgr.rssi,
                      mgr.connectionState,
                      mgr.isConnecting,
                      mgr.isSubscribed,
                      mgr.lastUpdated,
                      mgr.lastIntervalMs,
                    ),
                    builder: (context, data, _) {
                      return _HeartCard(
                        bpm: data.$1,
                        deviceName: data.$2,
                        rssi: data.$3,
                        state: data.$4,
                        isConnecting: data.$5,
                        isSubscribed: data.$6,
                        lastUpdated: data.$7,
                        intervalMs: data.$8,
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Consumer<HeartRateManager>(
                    builder: (context, mgr, _) => _ControlsRow(mgr: mgr),
                  ),
                  const SizedBox(height: 12),
                  Consumer<HeartRateManager>(
                    builder: (context, mgr, _) => _NearbyList(mgr: mgr),
                  ),
                  const SizedBox(height: 12),
                  Consumer<HeartRateManager>(
                    builder: (context, mgr, _) => _DebugList(mgr: mgr),
                  ),
                  const SizedBox(height: 8),
                ]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () async {
        final mgr = context.read<HeartRateManager>();
        final updated = await Navigator.of(context).push<HeartRateSettings>(
          CupertinoPageRoute(
            builder: (_) => SettingsPage(initial: mgr.settings),
          ),
        );
        if (updated != null) {
          await mgr.updateSettings(updated);
        }
      },
      child: const Icon(CupertinoIcons.gear, size: 22), minimumSize: Size(0, 0),
    );
  }
}

class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.status, required this.adapterState});

  final String status;
  final BluetoothAdapterState adapterState;

  @override
  Widget build(BuildContext context) {
    final toneColor = adapterState == BluetoothAdapterState.on
        ? AppColors.success
        : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _resolve(context, AppColors.bgSecondary),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(
          color: _resolve(context, AppColors.separator).withAlpha(70),
        ),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.asset(
              'images/logo.png',
              width: 36,
              height: 36,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '连接状态',
                  style: AppTypography.caption.copyWith(
                    color: _resolve(context, AppColors.textSecondary),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  status,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.callout.copyWith(
                    color: _resolve(context, AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(
            label: adapterState == BluetoothAdapterState.on ? '蓝牙已开' : '蓝牙关闭',
            color: _resolve(context, toneColor),
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha(28),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(color: color.withAlpha(140)),
      ),
      child: Text(label, style: AppTypography.caption.copyWith(color: color)),
    );
  }
}

class _HeartCard extends StatelessWidget {
  const _HeartCard({
    required this.bpm,
    required this.deviceName,
    required this.rssi,
    required this.state,
    required this.isConnecting,
    required this.isSubscribed,
    required this.lastUpdated,
    required this.intervalMs,
  }) : _formatter = const _UpdateFormatter();

  // 细分格式化逻辑，保持 Widget 本身简单
  final _UpdateFormatter _formatter;

  final int? bpm;
  final String deviceName;
  final int? rssi;
  final BluetoothConnectionState state;
  final bool isConnecting;
  final bool isSubscribed;
  final DateTime? lastUpdated;
  final int? intervalMs;

  @override
  Widget build(BuildContext context) {
    final statusText = isConnecting
        ? '连接中'
        : (state == BluetoothConnectionState.connected
              ? (isSubscribed ? '已连接' : '已连接 · 等待心率')
              : '未连接');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _resolve(context, AppColors.bgTertiary),
        borderRadius: BorderRadius.circular(AppRadius.r16),
        border: Border.all(
          color: _resolve(context, AppColors.separator).withAlpha(70),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _HeartbeatMeter(bpm: bpm),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bpm != null ? '$bpm bpm' : '-- bpm',
                  style: AppTypography.title1.copyWith(
                    color: _resolve(context, AppColors.textPrimary),
                    letterSpacing: -0.6,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      CupertinoIcons.device_phone_portrait,
                      color: _resolve(context, AppColors.textSecondary),
                      size: 14,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        deviceName,
                        style: AppTypography.footnote.copyWith(
                          color: _resolve(context, AppColors.textSecondary),
                        ),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    _RssiBadge(rssi: rssi),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: AppTypography.caption.copyWith(
                    color: _resolve(context, AppColors.textSecondary),
                  ),
                ),
                if (lastUpdated != null)
                  Text(
                    _formatter.format(lastUpdated!, intervalMs),
                    style: AppTypography.caption.copyWith(
                      color: _resolve(context, AppColors.textTertiary),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _HeartbeatMeter extends StatefulWidget {
  const _HeartbeatMeter({required this.bpm});

  final int? bpm;

  @override
  State<_HeartbeatMeter> createState() => _HeartbeatMeterState();
}

class _HeartbeatMeterState extends State<_HeartbeatMeter>
    with
        SingleTickerProviderStateMixin,
        WidgetsBindingObserver,
        WindowListener,
        TrayListener {
  late AnimationController _controller;
  late Animation<double> _scale;
  bool _appVisible = true;
  bool _windowVisible = true;
  bool _trayVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.addListener(this);
      // Minimized窗口不渲染首帧，异步获取一次可见性。
      windowManager.isVisible().then((visible) {
        if (!mounted) return;
        _windowVisible = visible;
        _updatePlayback();
      });

      if (Platform.isWindows) {
        trayManager.addListener(this);
      }
    }

    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.bpm),
      lowerBound: 0.0,
      upperBound: 1.0,
    );
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.12,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);

    _updatePlayback();
  }

  @override
  void didUpdateWidget(covariant _HeartbeatMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDuration = _durationFor(widget.bpm);
    if (_controller.duration != newDuration) {
      _controller.duration = newDuration;
      if (_controller.isAnimating) {
        _controller.forward(from: 0);
      }
    }
    _updatePlayback();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (!kIsWeb &&
        (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
      windowManager.removeListener(this);
      if (Platform.isWindows) {
        trayManager.removeListener(this);
        trayManager.destroy();
      }
    }
    _controller.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appVisible = state == AppLifecycleState.resumed;
    _updatePlayback();
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'minimize') {
      _windowVisible = false;
      if (Platform.isWindows) {
        _ensureTray();
        _trayVisible = true;
        unawaited(() async {
          await windowManager.setSkipTaskbar(true);
          await windowManager.hide();
        }());
      }
    } else if (eventName == 'restore' || eventName == 'focus') {
      _windowVisible = true;
      if (Platform.isWindows && _trayVisible) {
        unawaited(trayManager.destroy());
        _trayVisible = false;
      }
    }
    _updatePlayback();
  }

  @override
  void onTrayIconMouseDown() {
    if (!Platform.isWindows) return;
    unawaited(_restoreFromTray());
  }

  @override
  void onTrayIconRightMouseDown() {
    if (!Platform.isWindows) return;
    unawaited(_restoreFromTray());
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 88,
      height: 88,
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) {
          return Transform.scale(scale: _scale.value, child: child);
        },
        child: Container(
          decoration: BoxDecoration(
            color: _resolve(context, AppColors.fillSecondary),
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Icon(
            CupertinoIcons.heart_fill,
            color: _resolve(context, AppColors.heart),
            size: 52,
          ),
        ),
      ),
    );
  }

  Duration _durationFor(int? bpm) {
    if (bpm == null || bpm <= 0) return const Duration(milliseconds: 900);
    final clamped = bpm.clamp(40, 180);
    final ms = (60000 / clamped).round();
    return Duration(milliseconds: ms.clamp(450, 1200));
  }

  void _updatePlayback() {
    final shouldAnimate =
        _appVisible && _windowVisible && (widget.bpm ?? 0) > 0;
    if (shouldAnimate) {
      if (!_controller.isAnimating) {
        _controller.repeat();
      }
    } else {
      if (_controller.isAnimating) {
        _controller.stop();
      }
    }
  }

  Future<void> _updateTrayTooltip() async {
    if (!mounted) return;
    final mgr = context.read<HeartRateManager>();
    final bpm = mgr.heartRate;
    final connected = mgr.isConnected;
    final name = mgr.connectedName.isEmpty ? '未连接' : mgr.connectedName;
    final text = connected ? '在线 · $name · 心率 ${bpm ?? '--'}' : '未连接';
    await trayManager.setToolTip(text);
  }

  Future<void> _ensureTray() async {
    if (!_trayVisible) {
      await trayManager.setIcon(_trayIconPath());
    }
    await _updateTrayTooltip();
  }

  String _trayIconPath() {
    if (Platform.isWindows) {
      return 'images/logo.ico';
    }
    return 'images/logo.png';
  }

  Future<void> _restoreFromTray() async {
    _windowVisible = true;
    _updatePlayback();

    try {
      await windowManager.setSkipTaskbar(false);
    } catch (_) {}

    try {
      await windowManager.show();
      await windowManager.restore();
      await windowManager.focus();
    } catch (_) {}

    if (_trayVisible) {
      try {
        await trayManager.destroy();
      } catch (_) {}
      _trayVisible = false;
    }
  }
}

class _UpdateFormatter {
  const _UpdateFormatter();
  String format(DateTime time, int? intervalMs) {
    final ts =
        '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}:${time.second.toString().padLeft(2, '0')}';
    if (intervalMs == null) return '更新 $ts';
    return '更新 $ts (+${intervalMs}ms)';
  }
}

class _RssiBadge extends StatelessWidget {
  const _RssiBadge({required this.rssi});

  final int? rssi;

  @override
  Widget build(BuildContext context) {
    final strength = rssi;
    final tone = strength == null
        ? _resolve(context, AppColors.textTertiary)
        : strength > -60
        ? _resolve(context, AppColors.success)
        : strength > -75
        ? _resolve(context, AppColors.warning)
        : _resolve(context, AppColors.danger);
    final textColor = strength == null
        ? _resolve(context, AppColors.textTertiary)
        : _resolve(context, AppColors.textSecondary);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: _resolve(context, AppColors.fillSecondary),
        borderRadius: BorderRadius.circular(AppRadius.r10),
        border: Border.all(
          color: _resolve(context, AppColors.separator).withAlpha(90),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(CupertinoIcons.wifi, size: 12, color: tone),
          const SizedBox(width: 4),
          Text(
            strength != null ? '$strength dBm' : '--',
            style: AppTypography.caption.copyWith(color: textColor),
          ),
        ],
      ),
    );
  }
}

class _ControlsRow extends StatelessWidget {
  const _ControlsRow({required this.mgr});

  final HeartRateManager mgr;

  bool _toggleEnabled(HeartRateManager mgr) {
    return mgr.canToggleConnection &&
        (!mgr.isConnecting ||
            mgr.connectionState == BluetoothConnectionState.connected);
  }

  String _toggleLabel(HeartRateManager mgr) {
    if (mgr.connectionState == BluetoothConnectionState.connected) {
      return '断开连接';
    }
    if (mgr.isConnecting) return '连接中...';
    if (mgr.isAutoReconnecting) return '自动重连中...';
    return '连接设备';
  }

  IconData _toggleIcon(HeartRateManager mgr) {
    if (mgr.connectionState == BluetoothConnectionState.connected) {
      return CupertinoIcons.link_circle_fill;
    }
    if (mgr.isConnecting || mgr.isAutoReconnecting) {
      return CupertinoIcons.arrow_2_circlepath;
    }
    return CupertinoIcons.link;
  }

  bool _scanEnabled(HeartRateManager mgr) {
    return mgr.canToggleConnection &&
        !mgr.uiScanning &&
        !mgr.isConnecting &&
        !mgr.isAutoReconnecting &&
        mgr.connectionState != BluetoothConnectionState.connected;
  }

  String _scanLabel(HeartRateManager mgr) {
    if (mgr.uiScanning) return '扫描中...';
    return '重新扫描';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: CupertinoButton.filled(
                onPressed: _toggleEnabled(mgr) ? mgr.toggleConnection : null,
                borderRadius: BorderRadius.circular(AppRadius.r12),
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 12,
                ),
                child: _ButtonContent(
                  icon: _toggleIcon(mgr),
                  label: _toggleLabel(mgr),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _OutlinedActionButton(
                onPressed: _scanEnabled(mgr) ? mgr.restartScan : null,
                icon: CupertinoIcons.antenna_radiowaves_left_right,
                label: _scanLabel(mgr),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Container(height: 0.5, color: _resolve(context, AppColors.separator)),
      ],
    );
  }
}

class _ButtonContent extends StatelessWidget {
  const _ButtonContent({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: CupertinoColors.white),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.callout.copyWith(color: CupertinoColors.white),
          ),
        ),
      ],
    );
  }
}

class _OutlinedActionButton extends StatelessWidget {
  const _OutlinedActionButton({
    required this.onPressed,
    required this.icon,
    required this.label,
  });

  final VoidCallback? onPressed;
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final borderColor = enabled
        ? _resolve(context, AppColors.separator)
        : _resolve(context, AppColors.separator).withAlpha(80);
    final textColor = enabled
        ? _resolve(context, AppColors.accent)
        : _resolve(context, AppColors.textTertiary);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: _resolve(context, AppColors.bgTertiary),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        border: Border.all(color: borderColor),
      ),
      child: CupertinoButton(
        onPressed: onPressed,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
        borderRadius: BorderRadius.circular(AppRadius.r12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 18, color: textColor),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.callout.copyWith(color: textColor),
              ),
            ),
          ],
        ), minimumSize: Size(44, 44),
      ),
    );
  }
}

class _NearbyList extends StatelessWidget {
  const _NearbyList({required this.mgr});

  final HeartRateManager mgr;

  @override
  Widget build(BuildContext context) {
    final devices = mgr.nearbyDevices.take(4).toList();
    return CupertinoListSection.insetGrouped(
      header: Row(
        children: [
          Icon(
            CupertinoIcons.antenna_radiowaves_left_right,
            color: _resolve(context, AppColors.accent),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '附近心率设备',
            style: AppTypography.caption.copyWith(
              color: _resolve(context, AppColors.textSecondary),
            ),
          ),
        ],
      ),
      children: devices.isEmpty
          ? [
              CupertinoListTile(
                leading: Icon(
                  CupertinoIcons.waveform,
                  color: _resolve(context, AppColors.textSecondary),
                ),
                title: Text(
                  '暂无广播',
                  style: AppTypography.callout.copyWith(
                    color: _resolve(context, AppColors.textPrimary),
                  ),
                ),
                subtitle: Text(
                  '保持蓝牙开启并靠近设备。',
                  style: AppTypography.caption.copyWith(
                    color: _resolve(context, AppColors.textSecondary),
                  ),
                ),
              ),
            ]
          : devices
                .map(
                  (d) => CupertinoListTile(
                    leading: Icon(
                      CupertinoIcons.device_phone_portrait,
                      color: _resolve(context, AppColors.textSecondary),
                    ),
                    title: Text(
                      d.name,
                      style: AppTypography.callout.copyWith(
                        color: _resolve(context, AppColors.textPrimary),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '${d.rssi} dBm',
                      style: AppTypography.caption.copyWith(
                        color: _resolve(context, AppColors.textSecondary),
                      ),
                    ),
                    trailing: CupertinoButton(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      borderRadius: BorderRadius.circular(AppRadius.r10),
                      color: _resolve(context, AppColors.fillSecondary),
                      onPressed: () => mgr.manualConnect(d),
                      child: Text(
                        '连接',
                        style: AppTypography.caption.copyWith(
                          color: _resolve(context, AppColors.accent),
                        ),
                      ), minimumSize: Size(44, 44),
                    ),
                  ),
                )
                .toList(),
    );
  }
}

class _DebugList extends StatelessWidget {
  const _DebugList({required this.mgr});

  final HeartRateManager mgr;

  @override
  Widget build(BuildContext context) {
    final results = mgr.debugScanResults.take(6).toList();
    if (results.isEmpty) return const SizedBox.shrink();

    return CupertinoListSection.insetGrouped(
      header: Row(
        children: [
          Icon(
            CupertinoIcons.info_circle,
            color: _resolve(context, AppColors.textSecondary),
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            '广播调试',
            style: AppTypography.caption.copyWith(
              color: _resolve(context, AppColors.textSecondary),
            ),
          ),
        ],
      ),
      children: results.map((r) {
        final adv = r.advertisementData;
        final services = adv.serviceUuids
            .map((e) => e.str.substring(0, 8))
            .join(', ');
        final mfr = adv.manufacturerData.isNotEmpty
            ? 'MFR ${adv.manufacturerData.length}B'
            : '无厂商数据';
        final name = adv.advName.isNotEmpty
            ? adv.advName
            : r.device.platformName;
        return CupertinoListTile(
          title: Text(
            '$name • ${r.rssi}dBm',
            style: AppTypography.callout.copyWith(
              color: _resolve(context, AppColors.textPrimary),
            ),
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${services.isNotEmpty ? services : '无UUID'} · $mfr',
            style: AppTypography.caption.copyWith(
              color: _resolve(context, AppColors.textSecondary),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.initial});

  final HeartRateSettings initial;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _pushCtrl;
  late final TextEditingController _oscCtrl;
  late final TextEditingController _oscConnectedCtrl;
  late final TextEditingController _oscValueCtrl;
  late final TextEditingController _oscPercentCtrl;
  late final TextEditingController _oscChatboxTemplateCtrl;
  late final TextEditingController _maxHrCtrl;
  late final TextEditingController _intervalCtrl;
  late final TextEditingController _mqttBrokerCtrl;
  late final TextEditingController _mqttPortCtrl;
  late final TextEditingController _mqttTopicCtrl;
  late final TextEditingController _mqttUsernameCtrl;
  late final TextEditingController _mqttPasswordCtrl;
  late final TextEditingController _mqttClientIdCtrl;
  bool _oscChatboxEnabled = false;

  @override
  void initState() {
    super.initState();
    _pushCtrl = TextEditingController(text: widget.initial.pushEndpoint);
    _oscCtrl = TextEditingController(
      text: widget.initial.oscAddress.isEmpty
          ? '127.0.0.1:9000'
          : widget.initial.oscAddress,
    );
    _oscConnectedCtrl = TextEditingController(
      text: widget.initial.oscHrConnectedPath,
    );
    _oscValueCtrl = TextEditingController(text: widget.initial.oscHrValuePath);
    _oscPercentCtrl = TextEditingController(
      text: widget.initial.oscHrPercentPath,
    );
    _oscChatboxEnabled = widget.initial.oscChatboxEnabled;
    _oscChatboxTemplateCtrl = TextEditingController(
      text: widget.initial.oscChatboxTemplate.isEmpty
          ? HeartRateSettings.defaults().oscChatboxTemplate
          : widget.initial.oscChatboxTemplate,
    );
    _maxHrCtrl = TextEditingController(
      text: widget.initial.maxHeartRate.toString(),
    );
    _intervalCtrl = TextEditingController(
      text: widget.initial.updateIntervalMs.toString(),
    );
    _mqttBrokerCtrl = TextEditingController(text: widget.initial.mqttBroker);
    _mqttPortCtrl = TextEditingController(
      text: widget.initial.mqttPort.toString(),
    );
    _mqttTopicCtrl = TextEditingController(text: widget.initial.mqttTopic);
    _mqttUsernameCtrl = TextEditingController(
      text: widget.initial.mqttUsername,
    );
    _mqttPasswordCtrl = TextEditingController(
      text: widget.initial.mqttPassword,
    );
    _mqttClientIdCtrl = TextEditingController(
      text: widget.initial.mqttClientId,
    );
  }

  @override
  void dispose() {
    _pushCtrl.dispose();
    _oscCtrl.dispose();
    _oscConnectedCtrl.dispose();
    _oscValueCtrl.dispose();
    _oscPercentCtrl.dispose();
    _oscChatboxTemplateCtrl.dispose();
    _maxHrCtrl.dispose();
    _intervalCtrl.dispose();
    _mqttBrokerCtrl.dispose();
    _mqttPortCtrl.dispose();
    _mqttTopicCtrl.dispose();
    _mqttUsernameCtrl.dispose();
    _mqttPasswordCtrl.dispose();
    _mqttClientIdCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text('配置'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: _onSave,
          child: const Text('保存'), minimumSize: Size(0, 0),
        ),
      ),
      child: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            CupertinoFormSection.insetGrouped(
              header: _sectionHeader('HTTP/WS 私有服务'),
              children: [
                _buildFormTextRow(
                  controller: _pushCtrl,
                  label: '推送地址',
                  placeholder: 'http:// 或 ws:// 开头',
                  helper: '用于 HTTP / WebSocket 推送',
                ),
                _buildFormTextRow(
                  controller: _intervalCtrl,
                  label: '间隔 (ms)',
                  placeholder: '默认 1000ms',
                  helper: '过低可能影响性能',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: _sectionHeader('VRChat OSC'),
              children: [
                _buildFormTextRow(
                  controller: _oscCtrl,
                  label: 'OSC 地址',
                  placeholder: '例如 127.0.0.1:9000',
                  helper: '目标主机与端口',
                ),
                _buildFormTextRow(
                  controller: _oscConnectedCtrl,
                  label: '在线状态',
                  placeholder: '/avatar/parameters/hr_connected',
                ),
                _buildFormTextRow(
                  controller: _oscValueCtrl,
                  label: '当前心率',
                  placeholder: '/avatar/parameters/hr_val',
                ),
                _buildFormTextRow(
                  controller: _oscPercentCtrl,
                  label: '心率百分比',
                  placeholder: '/avatar/parameters/hr_percent',
                ),
                _buildFormTextRow(
                  controller: _maxHrCtrl,
                  label: '最大心率',
                  placeholder: '默认 200',
                  helper: '心率百分比 = 当前心率 / 最大心率 × 100',
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: _sectionHeader('ChatBox 心率'),
              children: [
                CupertinoListTile(
                  title: Text(
                    'ChatBox 心率',
                    style: AppTypography.body.copyWith(
                      color: _resolve(context, AppColors.textPrimary),
                    ),
                  ),
                  subtitle: Text(
                    '在 VRChat 聊天框显示心率',
                    style: AppTypography.caption.copyWith(
                      color: _resolve(context, AppColors.textSecondary),
                    ),
                  ),
                  trailing: CupertinoSwitch(
                    value: _oscChatboxEnabled,
                    activeTrackColor: _resolve(context, AppColors.accent),
                    onChanged: (value) {
                      setState(() => _oscChatboxEnabled = value);
                    },
                  ),
                ),
                if (_oscChatboxEnabled)
                  _buildFormTextRow(
                    controller: _oscChatboxTemplateCtrl,
                    label: '文本内容',
                    placeholder: '例如：💓{hr}',
                    helper: '支持 {hr}/{percent}，最多 144 字符 / 9 行',
                  ),
              ],
            ),
            CupertinoFormSection.insetGrouped(
              header: _sectionHeader('MQTT 客户端'),
              children: [
                _buildFormTextRow(
                  controller: _mqttBrokerCtrl,
                  label: 'Broker',
                  placeholder: '例如 broker.example.com',
                  helper: '留空则不启用 MQTT',
                ),
                _buildFormTextRow(
                  controller: _mqttPortCtrl,
                  label: '端口',
                  placeholder: '1883',
                  keyboardType: TextInputType.number,
                ),
                _buildFormTextRow(
                  controller: _mqttTopicCtrl,
                  label: '发布 Topic',
                  placeholder: 'hr_push',
                  helper: '将发送 JSON 心率/连接事件',
                ),
                _buildFormTextRow(
                  controller: _mqttUsernameCtrl,
                  label: '用户名',
                  placeholder: '可选',
                ),
                _buildFormTextRow(
                  controller: _mqttPasswordCtrl,
                  label: '密码',
                  placeholder: '可选',
                  obscureText: true,
                ),
                _buildFormTextRow(
                  controller: _mqttClientIdCtrl,
                  label: 'Client ID',
                  placeholder: '默认自动生成',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionHeader(String text) {
    return Text(
      text,
      style: AppTypography.caption.copyWith(
        color: _resolve(context, AppColors.textSecondary),
      ),
    );
  }

  Widget _buildFormTextRow({
    required TextEditingController controller,
    required String label,
    String? placeholder,
    String? helper,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return CupertinoFormRow(
      prefix: Text(
        label,
        style: AppTypography.body.copyWith(
          color: _resolve(context, AppColors.textPrimary),
        ),
      ),
      helper: helper == null
          ? null
          : Text(
              helper,
              style: AppTypography.caption.copyWith(
                color: _resolve(context, AppColors.textSecondary),
              ),
            ),
      child: CupertinoTextField.borderless(
        controller: controller,
        placeholder: placeholder,
        keyboardType: keyboardType,
        obscureText: obscureText,
        textAlign: TextAlign.end,
        style: AppTypography.body.copyWith(
          color: _resolve(context, AppColors.textPrimary),
        ),
        placeholderStyle: AppTypography.body.copyWith(
          color: _resolve(context, AppColors.textTertiary),
        ),
        clearButtonMode: OverlayVisibilityMode.editing,
      ),
    );
  }

  void _onSave() {
    final cleanedPush = _pushCtrl.text.trim();
    final cleanedOsc = _oscCtrl.text.trim();
    final maxHr = int.tryParse(_maxHrCtrl.text.trim());

    final updated = widget.initial.copyWith(
      pushEndpoint: cleanedPush,
      oscAddress: cleanedOsc,
      oscHrConnectedPath: _oscConnectedCtrl.text.trim().isEmpty
          ? HeartRateSettings.defaults().oscHrConnectedPath
          : _oscConnectedCtrl.text.trim(),
      oscHrValuePath: _oscValueCtrl.text.trim().isEmpty
          ? HeartRateSettings.defaults().oscHrValuePath
          : _oscValueCtrl.text.trim(),
      oscHrPercentPath: _oscPercentCtrl.text.trim().isEmpty
          ? HeartRateSettings.defaults().oscHrPercentPath
          : _oscPercentCtrl.text.trim(),
      oscChatboxEnabled: _oscChatboxEnabled,
      oscChatboxTemplate: _oscChatboxTemplateCtrl.text.trim().isEmpty
          ? HeartRateSettings.defaults().oscChatboxTemplate
          : _oscChatboxTemplateCtrl.text.trim(),
      maxHeartRate: maxHr ?? widget.initial.maxHeartRate,
      updateIntervalMs:
          int.tryParse(_intervalCtrl.text.trim()) ??
          widget.initial.updateIntervalMs,
      mqttBroker: _mqttBrokerCtrl.text.trim(),
      mqttPort:
          int.tryParse(_mqttPortCtrl.text.trim()) ??
          HeartRateSettings.defaults().mqttPort,
      mqttTopic: _mqttTopicCtrl.text.trim().isEmpty
          ? HeartRateSettings.defaults().mqttTopic
          : _mqttTopicCtrl.text.trim(),
      mqttUsername: _mqttUsernameCtrl.text.trim(),
      mqttPassword: _mqttPasswordCtrl.text,
      mqttClientId: _mqttClientIdCtrl.text.trim(),
    );

    Navigator.of(context).pop(updated);
  }
}
