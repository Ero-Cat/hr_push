import 'dart:async';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (_blePluginSupported) {
    FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);
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
      title: 'OSC/HTTP心率推送',
      backgroundColor: Color(0xFF0B1220),
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
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: '心率推送',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0FA3B1)),
          useMaterial3: true,
          visualDensity: VisualDensity.compact,
        ),
        home: const HeartDashboard(),
      ),
    );
  }
}

class HeartDashboard extends StatelessWidget {
  const HeartDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                const contentPadding = EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 14,
                );
                final minHeight =
                    constraints.maxHeight > contentPadding.vertical
                    ? constraints.maxHeight - contentPadding.vertical
                    : 0.0;
                return SingleChildScrollView(
                  padding: contentPadding,
                  physics: const ClampingScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: minHeight),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Selector<
                          HeartRateManager,
                          (String, BluetoothAdapterState)
                        >(
                          selector: (_, mgr) => (mgr.status, mgr.adapterState),
                          builder: (context, data, _) {
                            return _Header(
                              status: data.$1,
                              adapterState: data.$2,
                            );
                          },
                        ),
                        const SizedBox(height: 18),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: const Color(0xFF111827),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.white10),
                          ),
                          child: Column(
                            children: [
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
                                  mgr.connectedName.isEmpty
                                      ? '未连接'
                                      : mgr.connectedName,
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
                              const SizedBox(height: 16),
                              Consumer<HeartRateManager>(
                                builder: (context, mgr, _) =>
                                    _ControlsRow(mgr: mgr),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        Consumer<HeartRateManager>(
                          builder: (context, mgr, _) => _NearbyList(mgr: mgr),
                        ),
                        const SizedBox(height: 10),
                        Consumer<HeartRateManager>(
                          builder: (context, mgr, _) => _DebugList(mgr: mgr),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              },
            ),
            Positioned(top: 14, right: 8, child: const _SettingsFab()),
          ],
        ),
      ),
    );
  }
}

class _SettingsFab extends StatelessWidget {
  const _SettingsFab();

  @override
  Widget build(BuildContext context) {
    return _TopActionButton(
      icon: Icons.settings,
      label: '配置',
      onPressed: () async {
        final mgr = context.read<HeartRateManager>();
        final updated = await Navigator.of(context).push<HeartRateSettings>(
          MaterialPageRoute(
            builder: (_) => SettingsPage(initial: mgr.settings),
          ),
        );
        if (updated != null) {
          await mgr.updateSettings(updated);
        }
      },
    );
  }
}

class _TopActionButton extends StatelessWidget {
  const _TopActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        minimumSize: const Size(44, 44),
        tapTargetSize: MaterialTapTargetSize.padded,
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
      ),
      icon: Icon(icon, size: 18),
      label: Text(label),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.status, required this.adapterState});

  final String status;
  final BluetoothAdapterState adapterState;

  @override
  Widget build(BuildContext context) {
    final statusColor = adapterState == BluetoothAdapterState.on
        ? const Color(0xFF34D399)
        : const Color(0xFFF59E0B);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'images/logo.png',
                width: 30,
                height: 30,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 8),
            const Text(
              '心率推送',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.3,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          status,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: statusColor.withAlpha((statusColor.a * 255.0 * 0.9).round()),
            fontSize: 14,
          ),
        ),
      ],
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _HeartbeatMeter(bpm: bpm),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bpm != null ? '$bpm bpm' : '-- bpm',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 34,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1.0,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.watch, color: Colors.white70, size: 14),
                    const SizedBox(width: 6),
                    Text(
                      deviceName,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  statusText,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
                if (lastUpdated != null)
                  Text(
                    _formatter.format(lastUpdated!, intervalMs),
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
              ],
            ),
            const Spacer(),
            _RssiBadge(rssi: rssi),
          ],
        ),
      ],
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
        child: const Icon(Icons.favorite, color: Color(0xFFE11D48), size: 56),
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
    final color = strength == null
        ? Colors.white24
        : strength > -60
        ? const Color(0xFF34D399)
        : strength > -75
        ? const Color(0xFFF59E0B)
        : const Color(0xFFEF4444);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withAlpha((color.a * 255.0 * 0.18).round()),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withAlpha((color.a * 255.0 * 0.6).round()),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.network_wifi_3_bar, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            strength != null ? '$strength dBm' : '--',
            style: TextStyle(color: color, fontSize: 12),
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
      return Icons.link_off;
    }
    if (mgr.isConnecting || mgr.isAutoReconnecting) return Icons.sync;
    return Icons.link;
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
              child: FilledButton.icon(
                onPressed: _toggleEnabled(mgr) ? mgr.toggleConnection : null,
                icon: Icon(_toggleIcon(mgr)),
                label: Text(_toggleLabel(mgr)),
              ),
            ),
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _scanEnabled(mgr) ? mgr.restartScan : null,
              icon: const Icon(Icons.radar),
              label: Text(_scanLabel(mgr)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Divider(thickness: 0.6, color: Color(0xFF1F2937)),
      ],
    );
  }
}

class _NearbyList extends StatelessWidget {
  const _NearbyList({required this.mgr});

  final HeartRateManager mgr;

  @override
  Widget build(BuildContext context) {
    final devices = mgr.nearbyDevices.take(4).toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              Icon(Icons.waves, color: Color(0xFF67E8F9), size: 18),
              SizedBox(width: 6),
              Text(
                '附近心率设备',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (devices.isEmpty)
            const Text(
              '暂无广播，保持蓝牙开启并靠近设备。',
              style: TextStyle(color: Colors.white38, fontSize: 12),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: devices
                  .map(
                    (d) => ActionChip(
                      label: SizedBox(
                        width: 160,
                        child: Text(
                          '${d.name} • ${d.rssi}dBm',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                          ),
                          overflow: TextOverflow.ellipsis,
                          softWrap: false,
                        ),
                      ),
                      avatar: const Icon(
                        Icons.watch,
                        color: Colors.white70,
                        size: 16,
                      ),
                      onPressed: () => mgr.manualConnect(d),
                      backgroundColor: const Color(0xFF1F2937),
                      shape: StadiumBorder(
                        side: BorderSide(color: Colors.white12),
                      ),
                    ),
                  )
                  .toList(),
            ),
        ],
      ),
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '广播调试',
            style: TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          ...results.map((r) {
            final adv = r.advertisementData;
            final services = adv.serviceUuids
                .map((e) => e.str.substring(0, 8))
                .join(', ');
            final mfr = adv.manufacturerData.isNotEmpty
                ? 'MFR ${adv.manufacturerData.length}B'
                : '无厂商数据';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${adv.advName.isNotEmpty ? adv.advName : r.device.platformName} • ${r.rssi}dBm',
                      style: const TextStyle(color: Colors.white, fontSize: 12),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    services.isNotEmpty ? services : '无UUID',
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    mfr,
                    style: const TextStyle(color: Colors.white38, fontSize: 11),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
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
    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0B1220),
        foregroundColor: Colors.white,
        title: const Text('配置'),
        elevation: 0,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _TopActionButton(
              icon: Icons.save_rounded,
              label: '保存',
              onPressed: _onSave,
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _sectionTitle('HTTP/WS 私有服务'),
            _buildTextField(
              controller: _pushCtrl,
              label: '推送地址',
              hint: 'http:// 或 ws:// 开头',
              helper: '用于 HTTP / WebSocket 推送',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _intervalCtrl,
              label: '推送/刷新间隔 (ms)',
              hint: '默认 1000ms，过低可能影响性能',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 20),
            _sectionTitle('VRChat OSC'),
            _buildTextField(
              controller: _oscCtrl,
              label: 'OSC 地址',
              hint: '例如 127.0.0.1:9000',
              helper: '目标主机与端口',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _oscConnectedCtrl,
              label: '心率在线状态',
              hint: '/avatar/parameters/hr_connected',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _oscValueCtrl,
              label: '当前心率数值',
              hint: '/avatar/parameters/hr_val',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _oscPercentCtrl,
              label: '心率百分比',
              hint: '/avatar/parameters/hr_percent',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _maxHrCtrl,
              label: '最大心率（心率百分比 = 当前心率 / 最大心率 × 100）',
              hint: '默认 200',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _buildSwitchTile(
              title: 'ChatBox 心率',
              subtitle: '在 VRChat 聊天框显示心率',
              value: _oscChatboxEnabled,
              onChanged: (value) {
                setState(() => _oscChatboxEnabled = value);
              },
            ),
            if (_oscChatboxEnabled) ...[
              const SizedBox(height: 10),
              _buildTextField(
                controller: _oscChatboxTemplateCtrl,
                label: 'ChatBox 文本内容',
                hint: '例如：🩷: {hr}',
                helper: '支持 {hr}/{percent}，最多 144 字符 / 9 行',
              ),
              const SizedBox(height: 10),
            ],
            const SizedBox(height: 20),
            _sectionTitle('MQTT 客户端'),
            _buildTextField(
              controller: _mqttBrokerCtrl,
              label: 'Broker 地址',
              hint: '例如 broker.example.com',
              helper: '留空则不启用 MQTT',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _mqttPortCtrl,
              label: 'Broker 端口',
              hint: '1883',
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _mqttTopicCtrl,
              label: '发布 Topic',
              hint: 'hr_push',
              helper: '将发送 JSON 心率/连接事件',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _mqttUsernameCtrl,
              label: '用户名 (可选)',
              hint: '',
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _mqttPasswordCtrl,
              label: '密码 (可选)',
              hint: '',
              obscureText: true,
            ),
            const SizedBox(height: 10),
            _buildTextField(
              controller: _mqttClientIdCtrl,
              label: 'Client ID (可选)',
              hint: '默认自动生成',
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    String? label,
    String? hint,
    String? helper,
    TextInputType? keyboardType,
    bool obscureText = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        helperText: helper,
        labelStyle: const TextStyle(color: Colors.white70),
        hintStyle: const TextStyle(color: Colors.white38),
        helperStyle: const TextStyle(color: Colors.white38),
        filled: true,
        fillColor: const Color(0xFF111827),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Colors.white12),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFF0FA3B1)),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
      ),
    );
  }

  Widget _buildSwitchTile({
    required String title,
    String? subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111827),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12),
      ),
      child: SwitchListTile.adaptive(
        value: value,
        onChanged: onChanged,
        activeColor: const Color(0xFF0FA3B1),
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontSize: 14),
        ),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
      ),
    );
  }

  Widget _buildInfoBox({required String title, required List<String> lines}) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          for (final line in lines)
            Padding(
              padding: const EdgeInsets.only(bottom: 2),
              child: Text(
                line,
                style: const TextStyle(color: Colors.white38, fontSize: 12),
              ),
            ),
        ],
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
