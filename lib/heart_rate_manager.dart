import 'dart:async';
import 'dart:collection';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';
import 'hr_notification_service.dart';
import 'ble/ble_adapter.dart';
import 'ble/ble_scanner.dart';
import 'ble/universal_ble_adapter.dart';
import 'models/models.dart';
import 'services/services.dart';



const String _heartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
const String _heartRateMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';

class HeartRateManager extends ChangeNotifier {
  HeartRateManager() : _pushCoordinator = PushCoordinator(onLog: _staticLog);

  static void _staticLog(String message, {Object? error}) {
    AppLog.info(message);
    if (error != null) AppLog.error('$message: $error');
  }

  // BLE Adapter for cross-platform support
  final BleAdapter _bleAdapter = UniversalBleAdapter();
  String? _connectedDeviceId;
  String? _connectedDeviceName;
  AdapterConnectionState _connectionState = AdapterConnectionState.disconnected;
  // Live Activities (Dynamic Island) removed per latest requirements.

  StreamSubscription<BleDeviceInfo>? _scanResultsSub;
  StreamSubscription<BleAdapterState>? _adapterStateSub;
  StreamSubscription<AdapterConnectionState>? _deviceStateSub;
  StreamSubscription<Uint8List>? _heartRateSub;

  // Push coordinator for all push services
  late final PushCoordinator _pushCoordinator;

  Timer? _reconnectTimer;
  Timer? _scanUiHoldTimer;
  Timer? _resubscribeTimer;

  Timer? _uiNotifyTimer;
  DateTime _lastUiNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _uiNotifyScheduled = false;
  DateTime? _lastPublished;
  bool _connecting = false;

  final HrNotificationService _notificationService = HrNotificationService();

  bool _autoReconnect = true;
  bool _userInitiatedDisconnect = false;
  bool _isScanning = false;
  bool _uiScanning = false;
  bool _isTestEnv = false;
  bool _autoConnectEnabled = false; // 首次启动不自动连接，等待用户操作
  bool _hrSubscribed = false;
  bool _hrOnline = false;
  bool _missingHrNotified = false;
  String? _savedDeviceId;
  String? _savedDeviceName;
  String? _pendingConnectName;
  SharedPreferences? _prefs;

  HeartRateSettings _settings = HeartRateSettings.defaults();

  int? _heartRate;
  int? _rssi;
  DateTime? _lastUpdated;
  DateTime? _lastHrSeenAt;
  String _status = '等待蓝牙...';
  BleAdapterState _adapterState = BleAdapterState.unknown;
  DateTime? _connectedAt;

  final List<NearbyDevice> _nearby = [];
  DateTime? _lastStatusChange;


  // 扫描周期 1000ms
  static const Duration _scanInterval = Duration(milliseconds: 1000);
  static const Duration _uiNotifyInterval = Duration(milliseconds: 200);
  // 为避免按钮闪烁，至少保持 3s 的"扫描中"显示
  static const Duration _scanUiMinVisible = Duration(seconds: 3);

  static const Duration _nearbyTtl = Duration(seconds: 8);
  static const Duration _hrStaleThreshold = Duration(seconds: 6);
  static const Duration _hrInitialOnlineGrace = Duration(seconds: 3);
  DateTime? _prevHeartRateAt;
  DateTime? _lastActionAt;
  static const Duration _actionCooldown = Duration(seconds: 2);
  Timer? _scanLoopTimer;
  bool _scanLoopStarting = false;
  int _reconnectAttempts = 0;

  static const Duration _gattStableDelay = Duration(milliseconds: 600);
  static const Duration _gattStableDelayWindows = Duration(milliseconds: 2000);

  UnmodifiableListView<NearbyDevice> get nearbyDevices =>
      UnmodifiableListView(_nearby);

  bool get isScanning => _isScanning;
  bool get uiScanning => _uiScanning;
  bool get isHeartRateFresh =>
      _lastUpdated != null &&
      DateTime.now().difference(_lastUpdated!) <= _hrStaleThreshold;
  bool get isConnecting => _connecting;
  bool get isAutoReconnecting => _reconnectTimer?.isActive ?? false;
  bool get isSubscribed => _hrSubscribed;
  bool get hrOnline => _hrOnline;
  bool get canToggleConnection {
    if (_lastActionAt == null) return true;
    return DateTime.now().difference(_lastActionAt!) >= _actionCooldown;
  }

  int? get heartRate => isHeartRateFresh ? _heartRate : null;
  int? get rssi =>
      _connectionState == AdapterConnectionState.connected ? _rssi : null;
  int? get lastIntervalMs => _lastUpdated != null && _prevHeartRateAt != null
      ? _lastUpdated!.difference(_prevHeartRateAt!).inMilliseconds
      : null;
  String get status => _status;
  DateTime? get lastUpdated => _lastUpdated;
  String get connectedName {
    if (_connectionState != AdapterConnectionState.connected) return '';
    return _connectedDeviceName ?? '';
  }
  String? get activeDeviceId => _connectedDeviceId;

  AdapterConnectionState get connectionState => _connectionState;
  BleAdapterState get adapterState => _adapterState;
  HeartRateSettings get settings => _settings;
  bool get isConnected =>
      _connectionState == AdapterConnectionState.connected;
  bool get isBluetoothOn => _adapterState == BleAdapterState.on;
  double? get _heartRatePercent {
    if (_heartRate == null || _settings.maxHeartRate <= 0) return null;
    final percent = _heartRate! / _settings.maxHeartRate;
    return percent.clamp(0, 1).toDouble();
  }

  @visibleForTesting
  static bool computeHrOnline({
    required bool userInitiatedDisconnect,
    required BleAdapterState adapterState,
    required AdapterConnectionState connectionState,
    required DateTime now,
    required DateTime? lastHeartRateAt,
    required DateTime? connectedAt,
    Duration hrFreshFor = _hrStaleThreshold,
    Duration initialGrace = _hrInitialOnlineGrace,
  }) {
    if (userInitiatedDisconnect) return false;
    if (adapterState != BleAdapterState.on) return false;

    final isFresh =
        lastHeartRateAt != null &&
        now.difference(lastHeartRateAt) <= hrFreshFor;
    if (isFresh) return true;

    if (connectionState == AdapterConnectionState.connected &&
        connectedAt != null &&
        now.difference(connectedAt) <= initialGrace) {
      return true;
    }

    return false;
  }

  void _syncHrOnline({DateTime? now, bool forceOsc = false}) {
    final t = now ?? DateTime.now();
    final next = computeHrOnline(
      userInitiatedDisconnect: _userInitiatedDisconnect,
      adapterState: _adapterState,
      connectionState: _connectionState,
      now: t,
      lastHeartRateAt: _lastHrSeenAt,
      connectedAt: _connectedAt,
    );

    final changed = next != _hrOnline;
    _hrOnline = next;
    if (changed || forceOsc) {
      unawaited(_sendOscConnectedIfNeeded(_hrOnline, force: forceOsc));
    }
  }

  void _setStatus(String value, {bool force = false}) {
    if (!force && _status == value) return;
    final now = DateTime.now();
    // 避免 UI 闪烁，状态更新至少间隔 500ms
    if (!force && _lastStatusChange != null) {
      final delta = now.difference(_lastStatusChange!);
      if (delta.inMilliseconds < 500) return;
    }
    _status = value;
    _lastStatusChange = now;
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

    _log('start');
    if (!_isBleSupportedPlatform) {
      _setStatus('当前平台暂不支持蓝牙扫描');
      _adapterState = BleAdapterState.off;
      notifyListeners();
      return;
    }

    // Initialize adapter
    _adapterState = await _bleAdapter.getAdapterState();

    final ready = await _ensurePermissionsAndBluetooth();
    if (!ready) return;

    _prefs = await SharedPreferences.getInstance();
    _settings = HeartRateSettings.fromPrefs(_prefs);
    AppLog.setEnabled(_settings.logEnabled);
    _savedDeviceId = _prefs?.getString('last_device_id');
    _savedDeviceName = _prefs?.getString('last_device_name');
    if (_savedDeviceId != null) {
      _autoConnectEnabled = true; // 曾连接过，自动尝试重连
    }

    if (Platform.isAndroid) {
      unawaited(() async {
        await _notificationService.initialize();
        final granted = await _notificationService.ensurePermission();
        if (!granted) {
          _setStatus('通知权限未授予，无法显示常驻心率卡片');
          notifyListeners();
          return;
        }
        await _notificationService.showDisconnected(status: _status);
      }());
    }

    _adapterStateSub = _bleAdapter.adapterStateStream.listen((state) {
      _adapterState = state;
      if (state != BleAdapterState.on) {
        _setStatus('请开启蓝牙');
      }
      _log('adapter state=$state');
      _syncHrOnline(now: DateTime.now(), forceOsc: true);
      notifyListeners();
    });

    _scanResultsSub = _bleAdapter.scanStream.listen(_handleScanResult);
    // UniversalBle doesn't expose isScanning stream directly, we manage it manually.

    _startScanLoopTimer();

    await _startScan();
    _syncHrOnline(now: DateTime.now(), forceOsc: true);
  }

  Future<bool> _ensurePermissionsAndBluetooth() async {
    if (!_isBleSupportedPlatform) {
      _setStatus('当前平台暂不支持蓝牙');
      notifyListeners();
      return false;
    }

    if (!await _bleAdapter.isBluetoothAvailable()) {
      _setStatus('蓝牙不可用');
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
        _setStatus('蓝牙/定位权限未授予');
        notifyListeners();
        return false;
      }
    }

    _log('permissions ok, adapter ready');
    return true;
  }

  void _startScanLoopTimer() {
    _scanLoopTimer?.cancel();
    _scanLoopTimer = Timer.periodic(_scanInterval, (_) {
      final now = DateTime.now();
      _pruneNearby(now);
      _checkStaleConnection(now);
      _syncHrOnline(now: now);
      _tryStartScan();
    });
  }

  void _checkStaleConnection(DateTime now) {
    if (_isTestEnv) return;
    if (_connecting) return;
    if (_connectionState != AdapterConnectionState.connected) return;

    final last = _lastUpdated ?? _prevHeartRateAt;
    if (last == null) return;

    // 若超过两倍心率失效阈值仍无数据，判定为掉线，主动重连（Windows 上常见）.
    if (now.difference(last) > _hrStaleThreshold * 2) {
      _log('stale connection, forcing reconnect');
      _setStatus('连接失活，自动重连...');
      _connectionState = AdapterConnectionState.disconnected;
      _connectedAt = null;
      // RSSI Polling removed
      unawaited(() async {
        try {
          if (_connectedDeviceId != null) {
            await _bleAdapter.disconnect(_connectedDeviceId!);
          }
        } catch (_) {}
      }());
      _notifyConnectionState();
      notifyListeners();
      _scheduleReconnect(immediate: true);
    }
  }

  Future<void> _tryStartScan() async {
    if (_isTestEnv || _scanLoopStarting) return;
    if (!_isBleSupportedPlatform) return;
    if (_isScanning) return;
    if (_connectionState == AdapterConnectionState.connected || _connecting) {
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

      _setStatus('扫描附近设备...');
      _setUiScanning(true);
      notifyListeners();
      _log('scan start');
      // Scan for devices with Heart Rate Service (or any if needed)
      // Note: Some bands don't advertise service UUIDs, so we scan all.
      await _bleAdapter.startScan();
    } catch (e) {
      _log('scan start failed', error: e);
      _setStatus('未连接', force: true);
      _setUiScanning(false);
      notifyListeners();
    }
  }

  Future<void> restartScan() async {
    if (_isTestEnv) return;
    if (!_isBleSupportedPlatform) {
      _setStatus('当前平台不支持蓝牙扫描');
      notifyListeners();
      return;
    }
    _log('restart scan');
    if (_connectionState == AdapterConnectionState.connected || _connecting) {
      _log('restartScan skipped: connected/connecting');
      return;
    }
    await _bleAdapter.stopScan();
    _nearby.clear();
    notifyListeners();
    await _startScan();
  }

  void _handleScanResult(BleDeviceInfo r) {
    if (_isLikelyPhoneOrPc(r)) return;
    if (!_isWearableHeartRateCandidate(r)) return;

    final now = DateTime.now();

    final name = NearbyDevice.fixWindowsDeviceName(r.name.trim().isNotEmpty ? r.name : '未命名设备');
    final id = r.id;

    final existingIndex = _nearby.indexWhere((d) => d.id == id);
    if (existingIndex >= 0) {
      _nearby[existingIndex]
        ..rssi = r.rssi
        ..connectable = r.connectable
        ..lastSeen = now;
    } else {
      _nearby.add(
        NearbyDevice(
          id: id,
          name: name,
          rssi: r.rssi,
          connectable: r.connectable,
          lastSeen: now,
        ),
      );
      _log(
        'scan found: $name ($id) rssi=${r.rssi} connectable=${r.connectable}',
      );
    }

    _updateBroadcastHeartRate(r);

    if (_userInitiatedDisconnect) {
      _pruneNearby(now);
      _nearby.sort((a, b) => b.rssi.compareTo(a.rssi));
      _notifyUi();
      return;
    }

    if (_autoConnectEnabled &&
        _shouldPrefer(r) &&
        (_savedDeviceId == null || _savedDeviceId == id) &&
        _connectionState != AdapterConnectionState.connected &&
        r.connectable) {
      _pendingConnectName = name;
      _log('auto connect: $name ($id)');
      _connectTo(id);
    }

    _pruneNearby(now);
    _nearby.sort((a, b) => b.rssi.compareTo(a.rssi));
    _notifyUi();
  }

  void _pruneNearby(DateTime now) {
    _nearby.removeWhere((d) => now.difference(d.lastSeen) > _nearbyTtl);
  }

  void _updateBroadcastHeartRate(BleDeviceInfo r) {
    final deviceName = NearbyDevice.fixWindowsDeviceName(r.name);
    
    if (_isXiaomiDevice(deviceName)) {
      _log('Xiaomi adv: name=$deviceName, uuids=[${r.serviceUuids.join(', ')}]');
    }
    
    final bpm = BleScanner.extractBroadcastHeartRate(r);
    if (bpm == null) return;

    final now = DateTime.now();
    _log('hr rx broadcast: bpm=$bpm rssi=${r.rssi} name=${r.name}');
    _prevHeartRateAt = _lastUpdated;
    _heartRate = bpm;
    _rssi = r.rssi;
    _lastUpdated = now;
    _lastHrSeenAt = now;
    _syncHrOnline(now: now);
    
    if (!_shouldPublishNow(now)) return;
    _lastPublished = now;
    _notifyHeartRateUpdate();
  }

  bool _shouldPrefer(BleDeviceInfo r) => BleScanner.shouldPrefer(r);
  bool _isXiaomiDevice(String name) => BleScanner.isXiaomiDevice(name);
  bool _isWearableHeartRateCandidate(BleDeviceInfo r) => BleScanner.isWearableHeartRateCandidate(r);
  bool _isLikelyPhoneOrPc(BleDeviceInfo r) => BleScanner.isLikelyPhoneOrPc(r);


  Future<void> _connectTo(String deviceId) async {
    if (_isTestEnv) return;
    if (!_isBleSupportedPlatform) {
      _setStatus('当前平台不支持蓝牙连接');
      notifyListeners();
      return;
    }
    if (_connecting) {
      return;
    }
    _connecting = true;
    _connectedDeviceId = deviceId;
    _userInitiatedDisconnect = false;
    _connectionState = AdapterConnectionState.disconnected;
    
    // Attempt to find device name from memory if possible
    final knownDevice = _nearby.firstWhere(
      (d) => d.id == deviceId, 
      orElse: () => NearbyDevice(
        id: deviceId, 
        name: _savedDeviceName ?? 'Unknown', 
        rssi: 0, 
        connectable: true, 
        lastSeen: DateTime.now()
      )
    );
    _connectedDeviceName = knownDevice.name;

    final label = (_pendingConnectName?.trim().isNotEmpty ?? false)
        ? _pendingConnectName!.trim()
        : NearbyDevice.fixWindowsDeviceName(knownDevice.name);
    _setStatus('正在连接 $label...');
    notifyListeners();
    _log('connect start: $deviceId name=$label');

    await _bleAdapter.stopScan();

    await _deviceStateSub?.cancel();
    _deviceStateSub = _bleAdapter.connectionStateStream(deviceId).listen((state) {
      _connectionState = state;
      if (state == AdapterConnectionState.connected) {
        _connectedAt = DateTime.now();
        _setStatus('已连接', force: true);
      }
      if (state == AdapterConnectionState.disconnected) {
        _connectedAt = null;
        _heartRateSub?.cancel();
        _hrSubscribed = false;
        _heartRate = null;
        _rssi = null;
        _lastUpdated = null;
        _prevHeartRateAt = null;
        _autoConnectEnabled = !_userInitiatedDisconnect;
        if (_userInitiatedDisconnect) {
          _autoReconnect = false;
          _connectedDeviceId = null;
          _connectedDeviceName = null;
          _deviceStateSub?.cancel();
        }
      }
      _log('connection state=$state');
      _notifyConnectionState();
      notifyListeners();
      if (state == AdapterConnectionState.disconnected &&
          !_userInitiatedDisconnect) {
        _reconnectAttempts = 0; // 重置退避，优先立即重连
        _scheduleReconnect(immediate: true);
      }
    });

    try {
      await _bleAdapter.connect(deviceId, timeout: const Duration(seconds: 10));
      
      _setStatus('已连接，订阅心率中...', force: true);
      
      _connectionState = AdapterConnectionState.connected;
      _connectedAt = DateTime.now();
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      notifyListeners();
      
      final name = (_pendingConnectName?.trim().isNotEmpty ?? false)
          ? _pendingConnectName!.trim()
          : NearbyDevice.fixWindowsDeviceName(knownDevice.name).trim();
      _pendingConnectName = null;
      _rememberLastDevice(deviceId, name);
      // RSSI polling removed for now as UniversalBle/BleAdapter interface simplification
      
      await _subscribeHeartRate(deviceId);
    } catch (e) {
      _log('connect failed', error: e);
      _setStatus(_formatErrorForStatus(e, fallback: '连接失败'), force: true);
      _connectionState = AdapterConnectionState.disconnected;
      _connectedAt = null;
      notifyListeners();
      await restartScan();
    } finally {
      _connecting = false;
      if (_connectionState != AdapterConnectionState.connected) {
        _pendingConnectName = null;
      }
      if (_connectionState != AdapterConnectionState.connected &&
          !_userInitiatedDisconnect &&
          _autoReconnect &&
          _connectedDeviceId != null &&
          !(_reconnectTimer?.isActive ?? false)) {
        _scheduleReconnect();
      }
      notifyListeners();
    }
  }

  Future<void> manualConnect(NearbyDevice target) async {
    if (!_isBleSupportedPlatform) {
      _setStatus('当前平台不支持蓝牙连接');
      notifyListeners();
      return;
    }
    _log('manual connect: ${target.name} (${target.id})');
    _autoReconnect = true; // 用户重新连接后恢复自动重连
    _autoConnectEnabled = true; // 用户主动操作后再允许自动连接
    _lastActionAt = DateTime.now();
    _pendingConnectName = target.name;
    await _connectTo(target.id);
  }

  Future<void> toggleConnection() async {
    if (_isTestEnv) return;
    if (!_isBleSupportedPlatform) return;
    if (!canToggleConnection) return;
    _lastActionAt = DateTime.now();

    if (isConnected || _connecting) {
      await disconnect();
      return;
    }

    _autoReconnect = true;
    _autoConnectEnabled = true;
    _userInitiatedDisconnect = false;

    final target = _selectPreferredDevice();
    if (target != null) {
      _pendingConnectName = target.name;
      await _connectTo(target.id);
      return;
    }

    _setStatus('等待设备广播...', force: true);
    notifyListeners();
    await restartScan();
  }

  NearbyDevice? _selectPreferredDevice() {
    if (_savedDeviceId != null) {
      for (final d in _nearby) {
        if (d.id == _savedDeviceId) return d;
      }
    }

    if (_savedDeviceName?.trim().isNotEmpty ?? false) {
      for (final d in _nearby) {
        if (d.name.trim() == _savedDeviceName!.trim()) return d;
      }
    }

    return _nearby.isNotEmpty ? _nearby.first : null;
  }

  Future<void> _subscribeHeartRate(
    String deviceId, {
    int attempt = 0,
  }) async {
    if (!_isBleSupportedPlatform) return;
    await _heartRateSub?.cancel();
    _resubscribeTimer?.cancel();
    _hrSubscribed = false;
    _missingHrNotified = false;
    _prevHeartRateAt = null;

    try {
      // 给设备短暂时间稳定 GATT，避免立即写 CCCD 报错
      final delay = Platform.isWindows
          ? _gattStableDelayWindows
          : _gattStableDelay;
      if (attempt == 0) {
        _setStatus('订阅心率中...', force: true);
      }
      await Future.delayed(delay);

      _log('subscribe hr attempt=$attempt');

      // Xiaomi devices often require pairing before exposing Heart Rate Service
      final deviceName = NearbyDevice.fixWindowsDeviceName(_connectedDeviceName ?? '');
      if (Platform.isWindows && _isXiaomiDevice(deviceName)) {
        _log('Xiaomi device detected, skipping explicit createBond (relying on OS pairing)');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Discover services
      _log('discovering services...');
      _setStatus('发现服务中...', force: true);
      notifyListeners();
      
      List<BleServiceInfo> services = [];
      const maxDiscoverRetries = 3;
      
      for (var retry = 0; retry < maxDiscoverRetries; retry++) {
        try {
          if (retry > 0) {
            _log('discoverServices retry $retry/$maxDiscoverRetries');
            await Future.delayed(Duration(milliseconds: 1000 + retry * 500));
          }
          
          services = await _bleAdapter.discoverServices(deviceId).timeout(
            const Duration(seconds: 10),
            onTimeout: () {
              throw TimeoutException('discoverServices timed out after 10s');
            },
          );
          break;
        } catch (e) {
          final errorStr = e.toString().toLowerCase();
          final isDeviceNotFound = errorStr.contains('device not found') ||
              errorStr.contains('not found');
          
          if (isDeviceNotFound && retry < maxDiscoverRetries - 1) {
            _log('discoverServices "Device not found", will retry...');
            continue;
          }
          _log('discoverServices failed: $e');
          rethrow;
        }
      }
      
      final serviceUuids = services.map((s) => s.uuid).join(', ');
      _log('discovered ${services.length} services: [$serviceUuids]');

      bool foundHr = false;
      for (final service in services) {
        // UniversalBle usually returns normalized UUIDs, but we should be careful with case
        if (service.uuid.toLowerCase() != _heartRateServiceUuid.toLowerCase()) continue;
        foundHr = true;
        
        for (final c in service.characteristics) {
          if (c.uuid.toLowerCase() == _heartRateMeasurementUuid.toLowerCase()) {
            final ok = await _enableHrNotifications(deviceId, c);
            if (ok) return;
          }
        }
      }
      
      if (!foundHr) {
         _log('HR service not found! Available services: $serviceUuids');
      }

      if (!_missingHrNotified) {
        _missingHrNotified = true;
        notifyListeners();
      }
      _scheduleResubscribe(deviceId, attempt: attempt + 1);
    } catch (e, stackTrace) {
      _log('subscribe hr failed: ${e.runtimeType} - $e\nStack: $stackTrace');
      if (e is PlatformException && attempt < 1) {
        _setStatus('订阅心率重试中...', force: true);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 800));
        if (_connectedDeviceId == deviceId &&
            _connectionState == AdapterConnectionState.connected) {
          await _subscribeHeartRate(deviceId, attempt: attempt + 1);
        }
        return;
      }

      _setStatus(_formatErrorForStatus(e, fallback: '订阅心率失败'), force: true);
      notifyListeners();
      _scheduleResubscribe(deviceId, attempt: attempt + 1);
    }
  }

  void _scheduleResubscribe(String deviceId, {required int attempt}) {
    if (attempt > 3) {
      _forceReconnect(reason: 'subscribe failed');
      return;
    }

    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(const Duration(seconds: 2), () {
      if (_connectedDeviceId == deviceId &&
          _connectionState == AdapterConnectionState.connected) {
        _subscribeHeartRate(deviceId, attempt: attempt);
      }
    });
  }

  Future<bool> _enableHrNotifications(String deviceId, BleCharacteristicInfo c) async {
    _log('enabling HR notifications for characteristic ${c.uuid}');
    const attempts = 2;
    for (var i = 0; i < attempts; i++) {
      try {
        _log('setNotifyValue attempt ${i + 1}/$attempts');
        
        // Setup listener first
        _heartRateSub = _bleAdapter.valueStream(deviceId, c.serviceUuid, c.uuid).listen(_handleHeartRateData);
        
        // Then enable notifications
        await _bleAdapter.subscribeToCharacteristic(deviceId, c.serviceUuid, c.uuid);
        
        _log('setNotifyValue succeeded');
        
        _resubscribeTimer?.cancel();
        _hrSubscribed = true;
        _missingHrNotified = false;
        _setStatus('已连接', force: true);
        return true;
      } catch (e) {
        _log('setNotifyValue failed attempt ${i + 1}', error: e);
        if (i < attempts - 1) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    return false;
  }

  void _handleHeartRateData(Uint8List data) {
    if (data.isEmpty) return;
    final bpm = BleScanner.parseHeartRateValue(data);
    if (bpm == null) return;
    final now = DateTime.now();
    _log('hr rx notify: bpm=$bpm');
    _prevHeartRateAt = _lastUpdated;
    _heartRate = bpm;
    _lastUpdated = now;
    _lastHrSeenAt = now;
    _syncHrOnline(now: now);
    final shouldPublish = _shouldPublishNow(now);
    if (!shouldPublish) return;

    _lastPublished = now;
    _notifyHeartRateUpdate();
    _notifyUi();
  }

  Future<void> disconnect() async {
    if (!_isBleSupportedPlatform) {
      _setStatus('当前平台不支持蓝牙连接');
      notifyListeners();
      return;
    }
    _log('disconnect requested');
    _lastActionAt = DateTime.now();
    _userInitiatedDisconnect = true;
    _reconnectTimer?.cancel();
    // RSSI Polling stopped
    _autoReconnect = false; // 手动断开后不再自动重连
    _autoConnectEnabled = false;
    _reconnectAttempts = 0;
    _connecting = false;
    _resubscribeTimer?.cancel();
    _setStatus('断开中...');
    _syncHrOnline(now: DateTime.now(), forceOsc: true);
    
    final deviceId = _connectedDeviceId;
    
    try {
      if (deviceId != null) {
        await _bleAdapter.disconnect(deviceId);
      }
      _connectionState = AdapterConnectionState.disconnected;
      _connectedAt = null;
    } finally {
      await _deviceStateSub?.cancel();
      await _heartRateSub?.cancel();
      _hrSubscribed = false;
      _connectedDeviceId = null;
      _connectedDeviceName = null;
      _rssi = null;
      _heartRate = null;
      _lastUpdated = null;
      _lastHrSeenAt = null;
      _prevHeartRateAt = null;
      _savedDeviceId = null;
      await _prefs?.remove('last_device_id');
      _savedDeviceName = null;
      await _prefs?.remove('last_device_name');
      _connectionState = AdapterConnectionState.disconnected;
      _connectedAt = null;
      _setStatus('已断开', force: true);
      _notifyConnectionState();
      notifyListeners();
      await Future.delayed(const Duration(milliseconds: 300));
      await restartScan();
    }
  }



  Future<void> _ensureScanAlive() async {
    if (!_isBleSupportedPlatform) return;
    if (_adapterState != BleAdapterState.on) return;
    if (_connectionState == AdapterConnectionState.connected || _connecting) {
      return;
    }
    
    // We don't have isScanning check from adapter, rely on internal state or just restart
    // If not connecting/connected and adapter on, ensure we are scanning if supposed to
    // But restartScan already handles checks.
    
    // For universal_ble, maybe we don't need aggressive restart? 
    // Just stop and start to be safe.
    await _bleAdapter.stopScan();
    await _startScan();
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (!_autoReconnect || _userInitiatedDisconnect) return;
    if (_reconnectTimer?.isActive ?? false) return;
    if (_connectedDeviceId != null) return; // Already connected logic handles re-connection?
    // Actually if _connectedDeviceId is not null but state is disconnected, we might need reconnect.
    // But usually we clear _connectedDeviceId on disconnect.
    
    // Logic: find target device ID and try to connect.
    final targetId = _savedDeviceId;
    if (targetId == null) return;

    // Exponential backoff
    _reconnectAttempts++;
    final delaySeconds = immediate
        ? 0
        : (_reconnectAttempts > 5
            ? 30
            : (_reconnectAttempts > 3 ? 10 : 3 * _reconnectAttempts));
    
    _log('scheduleReconnect in ${delaySeconds}s (attempt $_reconnectAttempts)');
    
    _reconnectTimer = Timer(Duration(seconds: delaySeconds), () async {
      _reconnectTimer = null;
      if (!_autoReconnect || _userInitiatedDisconnect) return;
      if (_connectionState == AdapterConnectionState.connected || _connecting) {
        return;
      }
      if (_adapterState != BleAdapterState.on) {
        // Bluetooth off, wait but keep attempts?
        _scheduleReconnect(); 
        return;
      }

      await _ensureScanAlive();

      NearbyDevice? nearby;
      try {
        nearby = _nearby.firstWhere((d) => d.id == targetId);
      } catch (_) {}

      if (nearby == null && (_savedDeviceName?.trim().isNotEmpty ?? false)) {
        final matches = _nearby
            .where(
              (d) => d.connectable && d.name.trim() == _savedDeviceName!.trim(),
            )
            .toList();
        if (matches.length == 1) {
          nearby = matches.first;
        }
      }

      if (nearby == null) {
        _setStatus('等待设备重新广播...');
        notifyListeners();
        _log('reconnect waiting for broadcast');
        _scheduleReconnect();
        return;
      }

      final deviceIdForReconnect = nearby.id;
      if (deviceIdForReconnect != _connectedDeviceId) {
        // Update target if shifted? Usually same ID.
      }

      _pendingConnectName = nearby.name;
      _setStatus('自动重连中...');
      notifyListeners();
      _log('auto reconnect: ${nearby.name} (${nearby.id})');
      await _connectTo(deviceIdForReconnect);
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
        // _isScanning is not tracked directly from stream anymore, 
        // rely on manual setting in _startScan/stopScan? 
        // Actually we set _uiScanning=true in _startScan. 
        // We need to unset it when scan stops.
        
        // For now, let UI scanning indicator turn off if we are connected.
        if (isConnected && _uiScanning) {
           _uiScanning = false;
           notifyListeners();
        }
      });
    } else {
      if (_scanUiHoldTimer?.isActive ?? false) {
        return; // Wait min visible time
      }
      if (_uiScanning) {
        _uiScanning = false;
        notifyListeners();
      }
    }
  }

  void _notifyUi({bool force = false}) {
    if (force) {
      _uiNotifyTimer?.cancel();
      _uiNotifyScheduled = false;
      _lastUiNotifyAt = DateTime.now();
      notifyListeners();
      return;
    }

    final now = DateTime.now();
    final elapsed = now.difference(_lastUiNotifyAt);
    if (elapsed >= _uiNotifyInterval) {
      _lastUiNotifyAt = now;
      notifyListeners();
      return;
    }

    if (_uiNotifyScheduled) return;
    _uiNotifyScheduled = true;
    _uiNotifyTimer?.cancel();
    _uiNotifyTimer = Timer(_uiNotifyInterval - elapsed, () {
      _uiNotifyScheduled = false;
      _lastUiNotifyAt = DateTime.now();
      notifyListeners();
    });
  }

  Future<void> _forceReconnect({required String reason}) async {
    _log('force reconnect: $reason');
    if (_connectedDeviceId == null) return;
    _setStatus('订阅心率失败，正在重连...', force: true);
    notifyListeners();

    try {
      await _bleAdapter.disconnect(_connectedDeviceId!);
    } catch (e) {
      _log('disconnect during force reconnect failed', error: e);
    }

    _connectionState = AdapterConnectionState.disconnected;
    _connectedAt = null;
    // RSSI stop removed
    await _heartRateSub?.cancel();
    _hrSubscribed = false;
    _notifyConnectionState();
    notifyListeners();
    _scheduleReconnect(immediate: true);
  }

  void _rememberLastDevice(String id, String name) {
    _savedDeviceId = id;
    _savedDeviceName = name;
    _prefs?.setString('last_device_id', id);
    if (name.trim().isNotEmpty) {
      _prefs?.setString('last_device_name', name);
    }
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
      'device': _connectedDeviceName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _log(
      'push event=heartRate bpm=$bpm percent=${percent == null ? '-' : (percent * 100).round()} connected=$connected',
    );

    unawaited(_sendPushPayload(payload));
    unawaited(_sendOscConnectedIfNeeded(_hrOnline, force: true));
    unawaited(_sendOscHeartRate(bpm, percent));
    unawaited(_sendOscChatboxIfNeeded(bpm, percent));

    unawaited(
      _notificationService.showConnected(
        deviceName: _connectedDeviceName ?? '',
        bpm: bpm,
        lastUpdated: _lastUpdated,
      ),
    );
  }

  void _notifyConnectionState() {
    _syncHrOnline(now: DateTime.now());
    final connected = isConnected;
    final payload = <String, dynamic>{
      'event': 'connection',
      'connected': connected,
      'device': _connectedDeviceName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _log('push event=connection connected=$connected');

    unawaited(_sendPushPayload(payload));
    if (connected) {
      unawaited(
        _notificationService.showConnected(
          deviceName: _connectedDeviceName ?? '',
          bpm: _heartRate,
          lastUpdated: _lastUpdated,
        ),
      );
    } else {
      unawaited(_notificationService.showDisconnected(status: _status));
    }
  }

  Future<void> _sendPushPayload(Map<String, dynamic> payload) async {
    final bpm = payload['heart_rate'] as int?;
    final timestamp = DateTime.tryParse(payload['timestamp'] as String? ?? '');
    final percent = payload['percent'] as double?;
    if (bpm == null || timestamp == null) return;
    
    await _pushCoordinator.sendHeartRate(
      bpm: bpm,
      percent: percent,
      timestamp: timestamp,
    );
  }

  Future<void> _sendOscConnectedIfNeeded(bool connected, {bool force = false}) async {
    await _pushCoordinator.sendConnectionStatus(connected, force: force);
  }

  Future<void> _sendOscHeartRate(int bpm, double? percent) async {
    // Now handled by _sendPushPayload via PushCoordinator
  }

  Future<void> _sendOscChatboxIfNeeded(int bpm, double? percent) async {
    await _pushCoordinator.sendChatbox(bpm, percent);
  }

  Future<void> updateSettings(HeartRateSettings value) async {
    final old = _settings;
    _settings = value;
    notifyListeners();
    await _settings.save(_prefs);

    // Update push coordinator settings
    _pushCoordinator.updateSettings(value);

    // Refresh OSC connected status if relevant settings changed
    final oscConnectedChanged =
        old.oscAddress != value.oscAddress ||
        old.oscHrConnectedPath != value.oscHrConnectedPath ||
        old.oscChatboxEnabled != value.oscChatboxEnabled ||
        old.oscChatboxTemplate != value.oscChatboxTemplate;
    if (oscConnectedChanged) {
      _syncHrOnline(now: DateTime.now(), forceOsc: true);
    }

    if (old.logEnabled != value.logEnabled) {
      AppLog.setEnabled(value.logEnabled);
    }
  }

  @override
  void dispose() {
    _log('dispose');
    _scanResultsSub?.cancel();
    _deviceStateSub?.cancel();
    _heartRateSub?.cancel();
    _adapterStateSub?.cancel();
    _reconnectTimer?.cancel();
    _scanUiHoldTimer?.cancel();
    _resubscribeTimer?.cancel();

    _scanLoopTimer?.cancel();
    _uiNotifyTimer?.cancel();
    _pushCoordinator.dispose();
    unawaited(_notificationService.cancel());
    super.dispose();
  }

  int? _androidMajorVersion() {
    final match = RegExp(
      r'Android (\d+)',
    ).firstMatch(Platform.operatingSystemVersion);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    if (error != null || stackTrace != null) {
      AppLog.error(message, error: error, stackTrace: stackTrace);
      return;
    }
    AppLog.info(message);
  }

  String _formatErrorForStatus(Object error, {required String fallback}) {
    if (error is PlatformException) {
      if (!kIsWeb && Platform.isWindows) {
        return '$fallback (code: ${error.code})';
      }
      final msg = (error.message ?? '').trim();
      if (msg.isNotEmpty) return '$fallback: $msg';
      final details = error.details?.toString().trim();
      if (details != null && details.isNotEmpty) {
        return '$fallback: $details';
      }
      return '$fallback (code: ${error.code})';
    }
    return '$fallback: $error';
  }
}
