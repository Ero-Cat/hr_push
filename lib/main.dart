import 'dart:io' show Platform;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:window_manager/window_manager.dart';

import 'heart_rate_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  FlutterBluePlus.setLogLevel(LogLevel.verbose, color: true);

  // Desktop: lock a consistent window size to keep layout consistent.
  if (!kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux)) {
    await windowManager.ensureInitialized();
    const size = Size(430, 820); // 紧凑桌面尺寸，接近手机竖屏
    final options = const WindowOptions(
      size: size,
      minimumSize: size,
      maximumSize: size,
      center: true,
      title: 'HR PUSH',
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
        title: 'HR PUSH',
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
    final mgr = context.watch<HeartRateManager>();

    return Scaffold(
      backgroundColor: const Color(0xFF0B1220),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight: constraints.maxHeight - 32,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _Header(status: mgr.status, adapterState: mgr.adapterState),
                    const SizedBox(height: 18),
                    _HeartCard(
                      bpm: mgr.heartRate,
                      deviceName: mgr.connectedName.isEmpty
                          ? '未连接'
                          : mgr.connectedName,
                      rssi: mgr.rssi,
                      state: mgr.connectionState,
                      lastUpdated: mgr.lastUpdated,
                    ),
                    const SizedBox(height: 18),
                    _ControlsRow(mgr: mgr),
                    const SizedBox(height: 12),
                    _NearbyList(mgr: mgr),
                    const SizedBox(height: 10),
                    _DebugList(mgr: mgr),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        ),
      ),
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
          children: const [
            Icon(Icons.favorite, color: Color(0xFF5EEAD4)),
            SizedBox(width: 8),
            Text(
              'HR PUSH',
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
          style: TextStyle(color: statusColor.withOpacity(.9), fontSize: 14),
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
    required this.lastUpdated,
  });

  final int? bpm;
  final String deviceName;
  final int? rssi;
  final BluetoothConnectionState state;
  final DateTime? lastUpdated;

  @override
  Widget build(BuildContext context) {
    final statusText = switch (state) {
      BluetoothConnectionState.connected => '已连接',
      BluetoothConnectionState.connecting => '连接中',
      BluetoothConnectionState.disconnecting => '断开中',
      _ => '未连接',
    };

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
                    '更新 ${lastUpdated!.hour.toString().padLeft(2, '0')}:${lastUpdated!.minute.toString().padLeft(2, '0')}',
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
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _durationFor(widget.bpm),
      lowerBound: 0.0,
      upperBound: 1.0,
    )..repeat();
    _scale = Tween<double>(
      begin: 0.9,
      end: 1.12,
    ).chain(CurveTween(curve: Curves.easeInOut)).animate(_controller);
  }

  @override
  void didUpdateWidget(covariant _HeartbeatMeter oldWidget) {
    super.didUpdateWidget(oldWidget);
    final newDuration = _durationFor(widget.bpm);
    if (_controller.duration != newDuration) {
      _controller.duration = newDuration;
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
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
        color: color.withOpacity(.18),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(.6)),
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

  bool _scanButtonEnabled(HeartRateManager mgr) {
    final connected = mgr.connectionState == BluetoothConnectionState.connected;
    return !mgr.uiScanning && !connected;
  }

  String _scanButtonLabel(HeartRateManager mgr) {
    if (mgr.connectionState == BluetoothConnectionState.connected) {
      return '已连接';
    }
    if (mgr.uiScanning) return '扫描中...';
    return '重新扫描';
  }

  IconData _scanButtonIcon(HeartRateManager mgr) {
    if (mgr.connectionState == BluetoothConnectionState.connected) {
      return Icons.check_circle;
    }
    return mgr.uiScanning ? Icons.sync : Icons.radar;
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
                onPressed: _scanButtonEnabled(mgr) ? mgr.restartScan : null,
                icon: Icon(_scanButtonIcon(mgr)),
                label: Text(_scanButtonLabel(mgr)),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.tonalIcon(
              onPressed:
                  mgr.connectionState == BluetoothConnectionState.connected
                  ? mgr.disconnect
                  : (mgr.nearbyDevices.isNotEmpty
                        ? () => mgr.manualConnect(mgr.nearbyDevices.first)
                        : null),
              icon: Icon(
                mgr.connectionState == BluetoothConnectionState.connected
                    ? Icons.link_off
                    : Icons.flash_on,
              ),
              label: Text(
                mgr.connectionState == BluetoothConnectionState.connected
                    ? '断开'
                    : '快速连接',
              ),
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
    return Column(
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
