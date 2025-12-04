import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform, RawDatagramSocket, InternetAddress;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

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

class HeartRateSettings {
  const HeartRateSettings({
    required this.pushEndpoint,
    required this.oscAddress,
    required this.oscHrConnectedPath,
    required this.oscHrValuePath,
    required this.oscHrPercentPath,
    required this.maxHeartRate,
    required this.updateIntervalMs,
  });

  final String pushEndpoint;
  final String oscAddress;
  final String oscHrConnectedPath;
  final String oscHrValuePath;
  final String oscHrPercentPath;
  final int maxHeartRate;
  final int updateIntervalMs;

  static const _defaultPushEndpoint = '';
  static const _defaultOscAddress = '127.0.0.1:9000';
  static const _defaultHrConnectedPath = '/avatar/parameters/hr_connected';
  static const _defaultHrValuePath = '/avatar/parameters/hr_val';
  static const _defaultHrPercentPath = '/avatar/parameters/hr_percent';
  static const _defaultMaxHeartRate = 200;
  static const _defaultUpdateIntervalMs = 1000;

  static const _kPushEndpointKey = 'cfg_push_endpoint';
  static const _kOscAddressKey = 'cfg_osc_address';
  static const _kOscConnectedKey = 'cfg_osc_connected_path';
  static const _kOscValueKey = 'cfg_osc_value_path';
  static const _kOscPercentKey = 'cfg_osc_percent_path';
  static const _kMaxHeartRateKey = 'cfg_max_heart_rate';
  static const _kUpdateIntervalKey = 'cfg_update_interval_ms';

  factory HeartRateSettings.defaults() {
    return const HeartRateSettings(
      pushEndpoint: _defaultPushEndpoint,
      oscAddress: _defaultOscAddress,
      oscHrConnectedPath: _defaultHrConnectedPath,
      oscHrValuePath: _defaultHrValuePath,
      oscHrPercentPath: _defaultHrPercentPath,
      maxHeartRate: _defaultMaxHeartRate,
      updateIntervalMs: _defaultUpdateIntervalMs,
    );
  }

  factory HeartRateSettings.fromPrefs(SharedPreferences? prefs) {
    if (prefs == null) return HeartRateSettings.defaults();

    return HeartRateSettings(
      pushEndpoint: prefs.getString(_kPushEndpointKey) ?? _defaultPushEndpoint,
      oscAddress: prefs.getString(_kOscAddressKey) ?? _defaultOscAddress,
      oscHrConnectedPath:
          prefs.getString(_kOscConnectedKey) ?? _defaultHrConnectedPath,
      oscHrValuePath: prefs.getString(_kOscValueKey) ?? _defaultHrValuePath,
      oscHrPercentPath:
          prefs.getString(_kOscPercentKey) ?? _defaultHrPercentPath,
      maxHeartRate: prefs.getInt(_kMaxHeartRateKey) ?? _defaultMaxHeartRate,
      updateIntervalMs:
          prefs.getInt(_kUpdateIntervalKey) ?? _defaultUpdateIntervalMs,
    );
  }

  Future<void> save(SharedPreferences? prefs) async {
    if (prefs == null) return;
    await prefs.setString(_kPushEndpointKey, pushEndpoint);
    await prefs.setString(_kOscAddressKey, oscAddress);
    await prefs.setString(_kOscConnectedKey, oscHrConnectedPath);
    await prefs.setString(_kOscValueKey, oscHrValuePath);
    await prefs.setString(_kOscPercentKey, oscHrPercentPath);
    await prefs.setInt(_kMaxHeartRateKey, maxHeartRate);
    await prefs.setInt(_kUpdateIntervalKey, updateIntervalMs);
  }

  HeartRateSettings copyWith({
    String? pushEndpoint,
    String? oscAddress,
    String? oscHrConnectedPath,
    String? oscHrValuePath,
    String? oscHrPercentPath,
    int? maxHeartRate,
    int? updateIntervalMs,
  }) {
    return HeartRateSettings(
      pushEndpoint: pushEndpoint ?? this.pushEndpoint,
      oscAddress: oscAddress ?? this.oscAddress,
      oscHrConnectedPath: oscHrConnectedPath ?? this.oscHrConnectedPath,
      oscHrValuePath: oscHrValuePath ?? this.oscHrValuePath,
      oscHrPercentPath: oscHrPercentPath ?? this.oscHrPercentPath,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      updateIntervalMs: updateIntervalMs ?? this.updateIntervalMs,
    );
  }
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

  IOWebSocketChannel? _wsChannel;
  bool _wsConnecting = false;
  RawDatagramSocket? _oscSocket;

  Timer? _reconnectTimer;
  Timer? _scanUiHoldTimer;
  DateTime? _lastPublished;
  bool _connecting = false;

  bool _autoReconnect = true;
  bool _userInitiatedDisconnect = false;
  bool _isScanning = false;
  bool _uiScanning = false;
  bool _isTestEnv = false;
  bool _autoConnectEnabled = false; // 首次启动不自动连接，等待用户操作
  String? _savedDeviceId;
  SharedPreferences? _prefs;

  HeartRateSettings _settings = HeartRateSettings.defaults();

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
  static const Duration _nearbyTtl = Duration(seconds: 8);
  static const Duration _reconnectDelay = Duration(seconds: 3);
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
  HeartRateSettings get settings => _settings;
  bool get isConnected =>
      _connectionState == BluetoothConnectionState.connected;
  double? get _heartRatePercent {
    if (_heartRate == null || _settings.maxHeartRate <= 0) return null;
    final percent = _heartRate! / _settings.maxHeartRate;
    return percent.clamp(0, 1).toDouble();
  }

  bool _shouldPublishNow(DateTime now) {
    final interval = Duration(milliseconds: _settings.updateIntervalMs);
    if (_lastPublished == null) return true;
    return now.difference(_lastPublished!) >= interval;
  }

  bool get _isBleSupportedPlatform {
    if (kIsWeb) return false;
    return Platform.isAndroid ||
        Platform.isIOS ||
        Platform.isMacOS ||
        Platform.isLinux ||
        Platform.isWindows;
  }

  Future<void> start() async {
    _isTestEnv = !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';
    if (_isTestEnv) return;

    if (!_isBleSupportedPlatform) {
      _status = '当前平台暂不支持蓝牙扫描';
      _adapterState = BluetoothAdapterState.off;
      notifyListeners();
      return;
    }

    final ready = await _ensurePermissionsAndBluetooth();
    if (!ready) return;

    _prefs = await SharedPreferences.getInstance();
    _settings = HeartRateSettings.fromPrefs(_prefs);
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
    if (!_isBleSupportedPlatform) {
      _status = '当前平台暂不支持蓝牙';
      notifyListeners();
      return false;
    }

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
    _scanLoopTimer = Timer.periodic(_scanInterval, (_) {
      _pruneNearby(DateTime.now());
      _tryStartScan();
    });
  }

  Future<void> _tryStartScan() async {
    if (_isTestEnv || _scanLoopStarting) return;
    if (!_isBleSupportedPlatform) return;
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
    if (!_isBleSupportedPlatform) return;
    try {
      _status = '扫描附近设备...';
      _setUiScanning(true);
      notifyListeners();
      await FlutterBluePlus.startScan(
        timeout: _scanInterval,
        // 一些腕表并不会在广播里声明心率服务, 所以不加 withServices 过滤
        continuousUpdates: true,
      );
    } catch (e) {
      _status = '未连接';
      _setUiScanning(false);
      notifyListeners();
    }
  }

  Future<void> restartScan() async {
    if (_isTestEnv) return;
    if (!_isBleSupportedPlatform) {
      _status = '当前平台不支持蓝牙扫描';
      notifyListeners();
      return;
    }
    await FlutterBluePlus.stopScan();
    _nearby.clear();
    notifyListeners();
    await _startScan();
  }

  void _handleScanResults(List<ScanResult> results) {
    final now = DateTime.now();
    for (final r in results) {
      if (_isLikelyPhoneOrPc(r)) continue;
      if (!_isWearableHeartRateCandidate(r)) continue;

      final name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : '未命名设备');

      final id = r.device.remoteId.str;
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

    _pruneNearby(now);
    _nearby.sort((a, b) => b.rssi.compareTo(a.rssi));
    notifyListeners();
  }

  void _pruneNearby(DateTime now) {
    _nearby.removeWhere((d) => now.difference(d.lastSeen) > _nearbyTtl);
  }

  void _updateBroadcastHeartRate(ScanResult r) {
    final data = r.advertisementData.serviceData[_heartRateService];
    if (data == null || data.length < 2) return;

    final bpm = _parseHeartRateValue(data);
    if (bpm == null) return;

    final now = DateTime.now();
    if (!_shouldPublishNow(now)) return;

    _heartRate = bpm;
    _rssi = r.rssi;
    _lastUpdated = now;
    _lastPublished = now;
    _status = '广播心率';
    _notifyHeartRateUpdate();
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
    if (!_isBleSupportedPlatform) {
      _status = '当前平台不支持蓝牙连接';
      notifyListeners();
      return;
    }
    if (_connecting) {
      return;
    }
    _connecting = true;
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
      _notifyConnectionState();
      notifyListeners();
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect) {
        _scheduleReconnect();
      }
    });

    try {
      await device.connect(
        timeout: const Duration(seconds: 10),
        autoConnect: false,
      );
      _status = '已连接 ${device.platformName}';
      _rssi = await device.readRssi();
      notifyListeners();
      _rememberLastDevice(device.remoteId.str);
      await _subscribeHeartRate(device);
    } catch (e) {
      _status = '连接失败: $e';
      notifyListeners();
      await restartScan();
      _scheduleReconnect();
    } finally {
      _connecting = false;
    }
  }

  Future<void> manualConnect(NearbyDevice target) async {
    if (!_isBleSupportedPlatform) {
      _status = '当前平台不支持蓝牙连接';
      notifyListeners();
      return;
    }
    _autoReconnect = true; // 用户重新连接后恢复自动重连
    _autoConnectEnabled = true; // 用户主动操作后再允许自动连接
    await _connectTo(target.device);
  }

  Future<void> _subscribeHeartRate(
    BluetoothDevice device, {
    int attempt = 0,
  }) async {
    if (!_isBleSupportedPlatform) return;
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
    final now = DateTime.now();
    if (!_shouldPublishNow(now)) return;

    _heartRate = bpm;
    _lastUpdated = now;
    _lastPublished = now;
    _status = '实时更新';
    _notifyHeartRateUpdate();
    notifyListeners();
  }

  Future<void> disconnect() async {
    if (!_isBleSupportedPlatform) {
      _status = '当前平台不支持蓝牙连接';
      notifyListeners();
      return;
    }
    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();
    _autoReconnect = false; // 手动断开后不再自动重连
    _autoConnectEnabled = false;
    try {
      await _connectedDevice?.disconnect();
    } finally {
      _connectionState = BluetoothConnectionState.disconnected;
      _status = '已断开';
      _notifyConnectionState();
      notifyListeners();
      await restartScan();
    }
  }

  void _scheduleReconnect() {
    if (!_isBleSupportedPlatform) return;
    if (!_autoReconnect || _connectedDevice == null) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_reconnectDelay, () async {
      final target = _connectedDevice;
      if (target == null) return;

      final lastSeen = _nearby
          .firstWhere(
            (d) => d.id == target.remoteId.str,
            orElse: () => NearbyDevice(
              id: '',
              name: '',
              rssi: 0,
              device: target,
              lastSeen: DateTime.fromMillisecondsSinceEpoch(0),
            ),
          )
          .lastSeen;

      final fresh = DateTime.now().difference(lastSeen) <= _nearbyTtl * 2;
      if (!fresh) {
        _status = '等待设备重新广播...';
        notifyListeners();
        return;
      }

      await _connectTo(target);
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

  void _notifyHeartRateUpdate() {
    final bpm = _heartRate;
    if (bpm == null) return;
    final percent = _heartRatePercent;
    final connected = isConnected;

    final payload = <String, dynamic>{
      'event': 'heartRate',
      'heartRate': bpm,
      'percent': percent,
      'connected': connected,
      'device': _connectedDevice?.platformName,
      'timestamp': DateTime.now().toIso8601String(),
    };

    unawaited(_sendPushPayload(payload));
    unawaited(_sendOscHeartRate(bpm, percent));
  }

  void _notifyConnectionState() {
    final connected = isConnected;
    final payload = <String, dynamic>{
      'event': 'connection',
      'connected': connected,
      'device': _connectedDevice?.platformName,
      'timestamp': DateTime.now().toIso8601String(),
    };

    unawaited(_sendPushPayload(payload));
    unawaited(_sendOscConnected(connected));
  }

  Future<void> _sendPushPayload(Map<String, dynamic> payload) async {
    final endpoint = _settings.pushEndpoint.trim();
    if (endpoint.isEmpty) return;
    final uri = Uri.tryParse(endpoint);
    if (uri == null) return;

    if (uri.scheme.startsWith('ws')) {
      await _sendWs(uri, payload);
    } else if (uri.scheme.startsWith('http')) {
      await _sendHttp(uri, payload);
    }
  }

  Future<void> _sendHttp(Uri uri, Map<String, dynamic> payload) async {
    try {
      await http
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));
    } catch (_) {
      // 发送失败静默忽略，避免打断主流程
    }
  }

  Future<void> _sendWs(Uri uri, Map<String, dynamic> payload) async {
    if (_wsChannel == null || _wsChannel!.closeCode != null) {
      if (_wsConnecting) return;
      _wsConnecting = true;
      try {
        _wsChannel = IOWebSocketChannel.connect(
          uri,
          pingInterval: const Duration(seconds: 10),
        );
        _wsChannel!.stream.listen(
          (_) {},
          onError: (_) {
            _wsChannel = null;
          },
          onDone: () {
            _wsChannel = null;
          },
        );
      } catch (_) {
        _wsChannel = null;
      } finally {
        _wsConnecting = false;
      }
    }

    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode(payload));
      } catch (_) {}
    }
  }

  Future<void> _sendOscConnected(bool connected) async {
    await _sendOscMessage(_settings.oscHrConnectedPath, connected);
  }

  Future<void> _sendOscHeartRate(int bpm, double? percent) async {
    await _sendOscMessage(_settings.oscHrValuePath, bpm);
    if (percent != null) {
      await _sendOscMessage(_settings.oscHrPercentPath, percent);
    }
  }

  Future<void> _sendOscMessage(String address, Object value) async {
    final target = await _resolveOscTarget();
    if (target == null) return;
    final socket = await _ensureOscSocket();
    if (socket == null) return;

    final msg = _encodeOscMessage(address, [_oscArgFromValue(value)]);
    try {
      socket.send(msg, target.address, target.port);
    } catch (_) {}
  }

  Future<_OscTarget?> _resolveOscTarget() async {
    final raw = _settings.oscAddress.trim().isEmpty
        ? HeartRateSettings.defaults().oscAddress
        : _settings.oscAddress.trim();

    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final port = int.tryParse(parts.last);
    final hostStr = parts.sublist(0, parts.length - 1).join(':');
    final host = hostStr.isEmpty ? '127.0.0.1' : hostStr;

    InternetAddress? ip = InternetAddress.tryParse(host);
    if (ip == null) {
      try {
        final res = await InternetAddress.lookup(host);
        if (res.isNotEmpty) ip = res.first;
      } catch (_) {
        return null;
      }
    }

    if (ip == null || port == null) return null;
    return _OscTarget(ip, port);
  }

  Future<RawDatagramSocket?> _ensureOscSocket() async {
    if (_oscSocket != null) return _oscSocket;
    try {
      _oscSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      return _oscSocket;
    } catch (_) {
      return null;
    }
  }

  List<int> _encodeOscMessage(String address, List<_OscArg> args) {
    final data = <int>[];
    data.addAll(_oscString(address));

    final typeTags = StringBuffer(',');
    for (final a in args) {
      typeTags.write(a.tag);
    }
    data.addAll(_oscString(typeTags.toString()));

    for (final a in args) {
      if (a.data != null) {
        data.addAll(a.data!);
      }
    }
    return data;
  }

  List<int> _oscString(String value) {
    final bytes = utf8.encode(value);
    final out = <int>[...bytes, 0];
    while (out.length % 4 != 0) {
      out.add(0);
    }
    return out;
  }

  _OscArg _oscArgFromValue(Object value) {
    if (value is bool) {
      return _OscArg(value ? 'T' : 'F', null);
    }

    final data = ByteData(4)
      ..setFloat32(0, (value as num).toDouble(), Endian.big);
    return _OscArg('f', data.buffer.asUint8List());
  }

  Future<void> updateSettings(HeartRateSettings value) async {
    final old = _settings;
    _settings = value;
    notifyListeners();
    await _settings.save(_prefs);

    if (old.pushEndpoint != value.pushEndpoint) {
      _wsChannel?.sink.close();
      _wsChannel = null;
      _wsConnecting = false;
    }

    if (old.oscAddress != value.oscAddress) {
      _oscSocket?.close();
      _oscSocket = null;
    }
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
    _wsChannel?.sink.close();
    _oscSocket?.close();
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

class _OscArg {
  _OscArg(this.tag, this.data);

  final String tag;
  final List<int>? data;
}

class _OscTarget {
  _OscTarget(this.address, this.port);

  final InternetAddress address;
  final int port;
}
