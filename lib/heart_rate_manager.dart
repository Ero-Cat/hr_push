import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

final Guid _heartRateService = Guid('0000180d-0000-1000-8000-00805f9b34fb');
final Guid _heartRateMeasurement = Guid('00002a37-0000-1000-8000-00805f9b34fb');

class NearbyDevice {
  NearbyDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.device,
    required this.lastSeen,
  });

  final String id;
  final String name;
  int rssi;
  DateTime lastSeen;
  final BluetoothDevice device;
}

class HeartRateManager extends ChangeNotifier {
  HeartRateManager();

  final List<ScanResult> _scanResults = [];
  BluetoothDevice? _connectedDevice;
  BluetoothConnectionState _connectionState =
      BluetoothConnectionState.disconnected;
  // Live Activities (Dynamic Island) removed per latest requirements.

  StreamSubscription<List<ScanResult>>? _scanResultsSub;
  StreamSubscription<bool>? _isScanningSub;
  StreamSubscription<BluetoothConnectionState>? _deviceStateSub;
  StreamSubscription<List<int>>? _heartRateSub;
  StreamSubscription<BluetoothAdapterState>? _adapterStateSub;

  Timer? _reconnectTimer;
  Timer? _scanUiHoldTimer;

  bool _autoReconnect = true;
  bool _userInitiatedDisconnect = false;
  bool _isScanning = false;
  bool _uiScanning = false;
  bool _isTestEnv = false;
  bool _autoConnectEnabled = false; // 首次启动不自动连接，等待用户操作
  String? _savedDeviceId;
  SharedPreferences? _prefs;

  int? _heartRate;
  int? _rssi;
  DateTime? _lastUpdated;
  String _status = '等待蓝牙...';
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;

  final List<NearbyDevice> _nearby = [];

  // 扫描周期 1000ms
  static const Duration _scanInterval = Duration(milliseconds: 1000);
  // 为避免按钮闪烁，至少保持 3s 的“扫描中”显示
  static const Duration _scanUiMinVisible = Duration(seconds: 3);
  Timer? _scanLoopTimer;
  bool _scanLoopStarting = false;

  UnmodifiableListView<NearbyDevice> get nearbyDevices =>
      UnmodifiableListView(_nearby);

  UnmodifiableListView<ScanResult> get debugScanResults =>
      UnmodifiableListView(_scanResults);

  bool get isScanning => _isScanning;
  bool get uiScanning => _uiScanning;
  int? get heartRate => _heartRate;
  int? get rssi => _rssi;
  String get status => _status;
  DateTime? get lastUpdated => _lastUpdated;
  String get connectedName => _connectedDevice?.platformName ?? '';
  BluetoothConnectionState get connectionState => _connectionState;
  BluetoothAdapterState get adapterState => _adapterState;

  Future<void> start() async {
    _isTestEnv = !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';
    if (_isTestEnv) return;

    final ready = await _ensurePermissionsAndBluetooth();
    if (!ready) return;

    _prefs = await SharedPreferences.getInstance();
    _savedDeviceId = _prefs?.getString('last_device_id');
    if (_savedDeviceId != null) {
      _autoConnectEnabled = true; // 曾连接过，自动尝试重连
    }

    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (state != BluetoothAdapterState.on) {
        _status = '请开启蓝牙';
      }
      notifyListeners();
    });

    _scanResultsSub = FlutterBluePlus.scanResults.listen(_handleScanResults);
    _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      _setUiScanning(scanning);
    });

    _startScanLoopTimer();

    await _startScan();
  }

  Future<bool> _ensurePermissionsAndBluetooth() async {
    if (!await FlutterBluePlus.isSupported) {
      _status = '此设备不支持蓝牙';
      notifyListeners();
      return false;
    }

    if (Platform.isAndroid) {
      final androidVersion = _androidMajorVersion();
      final needsLocation = androidVersion != null && androidVersion <= 11;

      final requests = <Permission>[
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
        if (needsLocation) Permission.location,
      ];

      final results = await requests.request();

      final denied = results.values.any(
        (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
      );
      if (denied) {
        _status = '蓝牙/定位权限未授予';
        notifyListeners();
        return false;
      }

      // 弹系统对话框打开蓝牙
      await FlutterBluePlus.turnOn();
    }

    return true;
  }

  void _startScanLoopTimer() {
    _scanLoopTimer?.cancel();
    _scanLoopTimer = Timer.periodic(_scanInterval, (_) => _tryStartScan());
  }

  Future<void> _tryStartScan() async {
    if (_isTestEnv || _scanLoopStarting) return;
    if (_isScanning) return;
    if (_connectionState == BluetoothConnectionState.connected ||
        _connectionState == BluetoothConnectionState.connecting) {
      return;
    }

    _scanLoopStarting = true;
    try {
      await _startScan();
    } finally {
      _scanLoopStarting = false;
    }
  }

  Future<void> _startScan() async {
    if (_isTestEnv) return;
    try {
      _status = '扫描附近设备...';
      _setUiScanning(true);
      notifyListeners();
      await FlutterBluePlus.startScan(
        timeout: _scanInterval,
        // 一些腕表并不会在广播里声明心率服务, 所以不加 withServices 过滤
        continuousUpdates: true,
        // 已显式申请定位权限，这里就不重复向系统弹窗
        androidCheckLocationServices: false,
      );
    } catch (e) {
      _status = '未连接';
      _setUiScanning(false);
      notifyListeners();
    }
  }

  Future<void> restartScan() async {
    if (_isTestEnv) return;
    await FlutterBluePlus.stopScan();
    _nearby.clear();
    notifyListeners();
    await _startScan();
  }

  void _handleScanResults(List<ScanResult> results) {
    for (final r in results) {
      if (_isLikelyPhoneOrPc(r)) continue;
      if (!_isWearableHeartRateCandidate(r)) continue;

      final name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : '未命名设备');

      final id = r.device.remoteId.str;
      final now = DateTime.now();
      final existingIndex = _nearby.indexWhere((d) => d.id == id);
      if (existingIndex >= 0) {
        _nearby[existingIndex]
          ..rssi = r.rssi
          ..lastSeen = now;
      } else {
        _nearby.add(
          NearbyDevice(
            id: id,
            name: name,
            rssi: r.rssi,
            device: r.device,
            lastSeen: now,
          ),
        );
      }

      _updateBroadcastHeartRate(r);

      if (_autoConnectEnabled &&
          _shouldPrefer(r) &&
          (_savedDeviceId == null || _savedDeviceId == id) &&
          _connectionState != BluetoothConnectionState.connected &&
          // 广播模式设备通常不可连接，避免无意义的连接尝试
          r.advertisementData.connectable) {
        _connectTo(r.device);
      }
    }

    _nearby.sort((a, b) => b.rssi.compareTo(a.rssi));
    notifyListeners();
  }

  void _updateBroadcastHeartRate(ScanResult r) {
    final data = r.advertisementData.serviceData[_heartRateService];
    if (data == null || data.length < 2) return;

    final bpm = _parseHeartRateValue(data);
    if (bpm == null) return;

    _heartRate = bpm;
    _rssi = r.rssi;
    _lastUpdated = DateTime.now();
    _status = '广播心率';
    // Live Activity removed; no island update.
  }

  int? _parseHeartRateValue(List<int> data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final hr16 = (flags & 0x01) == 0x01;
    if (hr16 && data.length < 3) return null;

    return hr16 ? data[1] | (data[2] << 8) : data[1];
  }

  bool _shouldPrefer(ScanResult r) {
    if (_isLikelyPhoneOrPc(r)) return false;
    return _isWearableHeartRateCandidate(r);
  }

  bool _isWearableHeartRateCandidate(ScanResult r) {
    final hasHeartRateService = r.advertisementData.serviceUuids
        .map((e) => e.str.toLowerCase())
        .any((id) => id.contains('180d'));

    final name = r.advertisementData.advName.toLowerCase();
    final likelyHrWearable =
        name.contains('garmin') ||
        name.contains('enduro') ||
        name.contains('hrm') ||
        name.contains('polar') ||
        name.contains('wahoo') ||
        name.contains('coros') ||
        name.contains('suunto') ||
        name.contains('fitbit') ||
        name.contains('watch');

    return hasHeartRateService || likelyHrWearable;
  }

  bool _isLikelyPhoneOrPc(ScanResult r) {
    final name =
        (r.advertisementData.advName.isNotEmpty
                ? r.advertisementData.advName
                : r.device.platformName)
            .toLowerCase();

    const phoneKeywords = [
      'iphone',
      'ipad',
      'android',
      'pixel',
      'samsung',
      'galaxy',
      'huawei',
      'honor',
      'xiaomi',
      'redmi',
      'oneplus',
      'oppo',
      'vivo',
      'mi ',
    ];

    const pcKeywords = [
      'macbook',
      'mac ',
      'imac',
      'windows',
      'pc',
      'laptop',
      'desktop',
    ];

    return phoneKeywords.any(name.contains) || pcKeywords.any(name.contains);
  }

  Future<void> _connectTo(BluetoothDevice device) async {
    if (_isTestEnv) return;
    _connectedDevice = device;
    _userInitiatedDisconnect = false;
    _status = '正在连接 ${device.platformName}...';
    _connectionState = BluetoothConnectionState.connecting;
    notifyListeners();

    await FlutterBluePlus.stopScan();

    await _deviceStateSub?.cancel();
    _deviceStateSub = device.connectionState.listen((state) {
      _connectionState = state;
      if (state == BluetoothConnectionState.disconnected) {
        _heartRateSub?.cancel();
        _heartRate = null;
      }
      notifyListeners();
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect) {
        _scheduleReconnect();
      }
    });

    try {
      await device.connect(
        license: License.free,
        timeout: const Duration(seconds: 10),
      );
      _status = '已连接 ${device.platformName}';
      _rssi = await device.readRssi();
      notifyListeners();
      _rememberLastDevice(device.remoteId.str);
      await _subscribeHeartRate(device);
    } catch (e) {
      _status = '连接失败: $e';
      notifyListeners();
      _scheduleReconnect();
    }
  }

  Future<void> manualConnect(NearbyDevice target) async {
    _autoReconnect = true; // 用户重新连接后恢复自动重连
    _autoConnectEnabled = true; // 用户主动操作后再允许自动连接
    await _connectTo(target.device);
  }

  Future<void> _subscribeHeartRate(
    BluetoothDevice device, {
    int attempt = 0,
  }) async {
    await _heartRateSub?.cancel();
    _heartRate = null;
    _lastUpdated = null;

    try {
      // 给设备短暂时间稳定 GATT，避免立即写 CCCD 报错
      await Future.delayed(const Duration(milliseconds: 300));

      final services = await device.discoverServices();
      for (final service in services) {
        if (service.uuid != _heartRateService) continue;
        for (final c in service.characteristics) {
          if (c.uuid == _heartRateMeasurement) {
            final ok = await _enableHrNotifications(c);
            if (ok) return;
          }
        }
      }
      _status = '未找到心率特征';
      notifyListeners();
    } catch (e) {
      // 部分设备刚连接时立即写 CCCD/READ 可能报错，延迟重试一次
      if (e is PlatformException && attempt < 1) {
        _status = '订阅心率重试中...';
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 800));
        if (_connectedDevice == device &&
            _connectionState == BluetoothConnectionState.connected) {
          await _subscribeHeartRate(device, attempt: attempt + 1);
        }
        return;
      }

      _status = '订阅心率失败: $e';
      notifyListeners();
    }
  }

  Future<bool> _enableHrNotifications(BluetoothCharacteristic c) async {
    const attempts = 2;
    for (var i = 0; i < attempts; i++) {
      try {
        await c.setNotifyValue(true);
        _heartRateSub = c.lastValueStream.listen(_handleHeartRateData);
        await c.read();
        return true;
      } catch (e) {
        // 如果已经开启通知, 忽略重复错误
        if (e is PlatformException && e.code == 'setNotifyValue') {
          try {
            _heartRateSub = c.lastValueStream.listen(_handleHeartRateData);
            return true;
          } catch (_) {}
        }
        if (i < attempts - 1) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    return false;
  }

  void _handleHeartRateData(List<int> data) {
    final bpm = _parseHeartRateValue(data);
    if (bpm == null) return;
    _heartRate = bpm;
    _lastUpdated = DateTime.now();
    _status = '实时更新';
    notifyListeners();
  }

  Future<void> disconnect() async {
    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();
    _autoReconnect = false; // 手动断开后不再自动重连
    _autoConnectEnabled = false;
    try {
      await _connectedDevice?.disconnect();
    } finally {
      _connectionState = BluetoothConnectionState.disconnected;
      _status = '已断开';
      notifyListeners();
      await restartScan();
    }
  }

  void _scheduleReconnect() {
    if (!_autoReconnect || _connectedDevice == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 3), () async {
      if (_connectedDevice == null) return;
      await _connectTo(_connectedDevice!);
    });
  }

  void _setUiScanning(bool scanning) {
    if (scanning) {
      if (!_uiScanning) {
        _uiScanning = true;
        notifyListeners();
      }
      _scanUiHoldTimer?.cancel();
      _scanUiHoldTimer = Timer(_scanUiMinVisible, () {
        if (!_isScanning && _uiScanning) {
          _uiScanning = false;
          notifyListeners();
        }
      });
    } else {
      if (_scanUiHoldTimer?.isActive ?? false) {
        return; // 等待最小显示时间结束
      }
      if (_uiScanning) {
        _uiScanning = false;
        notifyListeners();
      }
    }
  }

  void _rememberLastDevice(String id) {
    _savedDeviceId = id;
    _prefs?.setString('last_device_id', id);
  }

  @override
  void dispose() {
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    _deviceStateSub?.cancel();
    _heartRateSub?.cancel();
    _adapterStateSub?.cancel();
    _reconnectTimer?.cancel();
    _scanUiHoldTimer?.cancel();
    _scanLoopTimer?.cancel();
    super.dispose();
  }

  int? _androidMajorVersion() {
    final match = RegExp(
      r'Android (\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
