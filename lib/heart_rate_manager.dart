import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_log.dart';
import 'hr_notification_service.dart';
import 'ble/ble_adapter.dart';
import 'ble/ble_connection_service.dart';
import 'ble/ble_scanner.dart';
import 'ble/universal_ble_adapter.dart';
import 'models/models.dart';
import 'services/services.dart';
import 'utils/utils.dart';

class HeartRateManager extends ChangeNotifier {
  HeartRateManager() {
    _pushCoordinator = PushCoordinator(
      onLog: _log,
      onOscStatusChanged: _handleOscStatusChanged,
    );
    // Initialize BleScanner with callbacks
    _scanner = BleScanner(
      onLog: _log,
      onDeviceFound: _onDeviceFound,
      onBroadcastHeartRate: _onBroadcastHeartRate,
    );
    // Initialize BleConnectionService
    _connectionService = BleConnectionService(
      adapter: _bleAdapter,
      onLog: _log,
      onStatusChange: _setStatus,
      onHeartRateData: _handleHeartRateData,
      onConnectionStateChange: _onConnectionStateChange,
      onHrServiceMissing: _handleHrServiceMissing,
    );
  }

  // BLE Scanner for device discovery
  late final BleScanner _scanner;

  // BLE Connection Service for connection management
  late final BleConnectionService _connectionService;

  // BLE Adapter for cross-platform support
  final BleAdapter _bleAdapter = UniversalBleAdapter();
  String? _connectedDeviceId;
  String? _connectedDeviceName;
  AdapterConnectionState _connectionState = AdapterConnectionState.disconnected;

  StreamSubscription<BleDeviceInfo>? _scanResultsSub;
  StreamSubscription<BleAdapterState>? _adapterStateSub;

  // Push coordinator for all push services
  late final PushCoordinator _pushCoordinator;

  Timer? _reconnectTimer;
  Timer? _scanUiHoldTimer;

  Timer? _uiNotifyTimer;
  DateTime _lastUiNotifyAt = DateTime.fromMillisecondsSinceEpoch(0);
  bool _uiNotifyScheduled = false;
  DateTime? _lastPublished;
  bool _connecting = false;

  final HrNotificationService _notificationService = HrNotificationService();

  bool _autoReconnect = true;
  bool _userInitiatedDisconnect = false;
  final bool _isScanning = false;
  bool _uiScanning = false;
  bool _isTestEnv = false;
  bool _autoConnectEnabled = false; // 首次启动不自动连接，等待用户操作
  bool _hrSubscribed = false;
  bool _hrOnline = false;
  String? _savedDeviceId;
  String? _savedDeviceName;
  String? _pendingConnectName;
  SharedPreferences? _prefs;

  HeartRateSettings _settings = HeartRateSettings.defaults();

  int? _heartRate;
  int? _publishedHeartRate;
  int? _rssi;
  DateTime? _lastUpdated;
  DateTime? _lastHrSeenAt;
  String _status = '等待蓝牙...';
  BleAdapterState _adapterState = BleAdapterState.unknown;
  DateTime? _connectedAt;

  DateTime? _lastStatusChange;

  // 扫描周期 1000ms
  static const Duration _scanInterval = Duration(milliseconds: 1000);
  static const Duration _uiNotifyInterval = Duration(milliseconds: 200);
  // 为避免按钮闪烁，至少保持 3s 的"扫描中"显示
  static const Duration _scanUiMinVisible = Duration(seconds: 3);

  static const Duration _hrStaleThreshold = Duration(seconds: 6);
  static const Duration _hrInitialOnlineGrace = Duration(seconds: 3);
  // 连接成功后从未收到心率的最长等待，超过视为无数据连接（如未开启心率广播的小米手表）
  static const Duration _noHrDataTimeout = Duration(seconds: 20);
  // 连续自动重连上限，超过后停止并等待用户手动操作
  static const int _maxReconnectAttempts = 10;
  DateTime? _prevHeartRateAt;
  DateTime? _lastActionAt;
  static const Duration _actionCooldown = Duration(seconds: 2);
  Timer? _scanLoopTimer;
  bool _scanLoopStarting = false;
  int _reconnectAttempts = 0;
  bool _xiaomiGuidePending = false;

  List<NearbyDevice> get nearbyDevices => _scanner.nearbyDevices;

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

  int? get heartRate => isHeartRateFresh ? _publishedHeartRate : null;
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
  OscStatus get oscStatus => _pushCoordinator.oscStatus;
  bool get isConnected => _connectionState == AdapterConnectionState.connected;
  bool get isBluetoothOn => _adapterState == BleAdapterState.on;
  bool get xiaomiGuidePending => _xiaomiGuidePending;
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

  bool get _isBleSupportedPlatform => PermissionHelper.isBleSupportedPlatform;

  Future<void> start() async {
    _isTestEnv = !kIsWeb && Platform.environment['FLUTTER_TEST'] == 'true';
    if (_isTestEnv) return;

    _log('start');

    // Load settings even on unsupported platforms (e.g. Linux) so they
    // persist across restarts and push services stay configurable.
    final prefs = await SharedPreferences.getInstance();
    _prefs = prefs;
    _settings = HeartRateSettings.fromPrefs(prefs);
    _pushCoordinator.updateSettings(_settings);
    AppLog.setEnabled(_settings.logEnabled);
    _savedDeviceId = prefs.getString('last_device_id');
    _savedDeviceName = prefs.getString('last_device_name');
    if (_savedDeviceId != null) {
      _autoConnectEnabled = true; // 曾连接过，自动尝试重连
    }

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

    if (Platform.isAndroid) {
      try {
        await _notificationService.initialize();
        final started = await _notificationService.start();
        if (!started) {
          _log('foreground service start failed');
        }
        final granted = await _notificationService.ensurePermission();
        if (!granted) {
          _setStatus('通知权限未授予，无法显示常驻心率卡片');
          notifyListeners();
        }
        await _notificationService.showDisconnected(status: _status);
      } catch (error, stackTrace) {
        _log(
          'foreground service initialization failed',
          error: error,
          stackTrace: stackTrace,
        );
      }
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
    final helper = PermissionHelper(bleAdapter: _bleAdapter, onLog: _log);
    final result = await helper.ensurePermissionsAndBluetooth();
    if (!result.success) {
      _setStatus(result.errorMessage ?? '权限检查失败');
      notifyListeners();
      return false;
    }
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

    if (!shouldForceReconnect(
      now: now,
      lastHeartRateAt: _lastUpdated ?? _prevHeartRateAt,
      connectedAt: _connectedAt,
    )) {
      return;
    }

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

  /// Decides whether a "connected" device should be force-reconnected.
  ///
  /// Falls back to [connectedAt] when no heart rate was ever received —
  /// without that fallback a zombie connection (device never sends data,
  /// e.g. a Xiaomi watch without heart-rate broadcast enabled) would never
  /// be detected.
  @visibleForTesting
  static bool shouldForceReconnect({
    required DateTime now,
    required DateTime? lastHeartRateAt,
    required DateTime? connectedAt,
  }) {
    final last = lastHeartRateAt ?? connectedAt;
    if (last == null) return false;

    final limit = lastHeartRateAt == null
        ? _noHrDataTimeout
        : _hrStaleThreshold * 2;
    return now.difference(last) > limit;
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
    _scanner.clearNearby();
    notifyListeners();
    await _startScan();
  }

  void _handleScanResult(BleDeviceInfo r) {
    // Delegate to BleScanner for device tracking
    _scanner.handleScanResult(r);

    // Check for auto-connect
    if (!_userInitiatedDisconnect &&
        _autoConnectEnabled &&
        BleScanner.shouldPrefer(r) &&
        (_savedDeviceId == null || _savedDeviceId == r.id) &&
        _connectionState != AdapterConnectionState.connected &&
        r.connectable &&
        !_connecting) {
      final name = NearbyDevice.fixWindowsDeviceName(r.name.trim());
      _pendingConnectName = name;
      _log('auto connect: $name (${r.id})');
      _connectTo(r.id);
    }

    _scanner.pruneNearby();
    _scanner.sortByRssi();
    _notifyUi();
  }

  void _pruneNearby(DateTime now) {
    _scanner.pruneNearby();
  }

  // BleScanner callbacks
  void _onDeviceFound(NearbyDevice device, bool isNew) {
    // Device tracking handled by BleScanner
  }

  void _onBroadcastHeartRate(int bpm, int rssi, String deviceName) {
    final now = DateTime.now();
    _prevHeartRateAt = _lastUpdated;
    _heartRate = bpm;
    _rssi = rssi;
    _lastUpdated = now;
    _lastHrSeenAt = now;
    _syncHrOnline(now: now);

    if (!_shouldPublishNow(now)) return;
    _lastPublished = now;
    _notifyHeartRateUpdate();
  }

  Future<void> _connectTo(String deviceId) async {
    if (_isTestEnv) return;
    if (!_isBleSupportedPlatform) {
      _setStatus('当前平台不支持蓝牙连接');
      notifyListeners();
      return;
    }
    if (_connecting) return;

    _connecting = true;
    _connectedDeviceId = deviceId;
    _userInitiatedDisconnect = false;
    _connectionState = AdapterConnectionState.disconnected;

    // Get device display name
    final knownDevice = nearbyDevices
        .where((d) => d.id == deviceId)
        .firstOrNull;
    final displayName = (_pendingConnectName?.trim().isNotEmpty ?? false)
        ? _pendingConnectName!.trim()
        : NearbyDevice.fixWindowsDeviceName(
            knownDevice?.name ?? _savedDeviceName ?? 'Unknown',
          );
    _connectedDeviceName = displayName;
    _pendingConnectName = null;

    notifyListeners();

    try {
      final success = await _connectionService.connect(
        deviceId,
        displayName: displayName,
      );

      if (success) {
        _connectionState = AdapterConnectionState.connected;
        _connectedAt = DateTime.now();
        _hrSubscribed = true;
        _reconnectTimer?.cancel();
        _reconnectAttempts = 0;
        _rememberLastDevice(deviceId, displayName);
      } else {
        _connectionState = AdapterConnectionState.disconnected;
        _scheduleReconnect();
      }
    } catch (e) {
      _log('connect failed', error: e);
      _setStatus(_formatErrorForStatus(e, fallback: '连接失败'), force: true);
      _connectionState = AdapterConnectionState.disconnected;
      _connectedAt = null;
      await restartScan();
    } finally {
      _connecting = false;
      notifyListeners();
    }
  }

  /// Handle connection state changes from BleConnectionService
  void _onConnectionStateChange(AdapterConnectionState state) {
    _connectionState = state;

    if (state == AdapterConnectionState.connected) {
      _connectedAt = DateTime.now();
    }

    if (state == AdapterConnectionState.disconnected) {
      _connectedAt = null;
      _hrSubscribed = false;
      _heartRate = null;
      _publishedHeartRate = null;
      _rssi = null;
      _lastUpdated = null;
      _prevHeartRateAt = null;
      _autoConnectEnabled = !_userInitiatedDisconnect;

      if (_userInitiatedDisconnect) {
        _autoReconnect = false;
        _connectedDeviceId = null;
        _connectedDeviceName = null;
      } else if (_autoReconnect && _connectedDeviceId != null) {
        // 注意：不在此处重置 _reconnectAttempts——每次断开都清零会让退避
        // 永远从头开始，抖动的设备会制造无限 0-3-6-9s 连接风暴。
        // 计数只在连接并订阅成功后（_connectTo 成功分支）重置。
        _scheduleReconnect(immediate: true);
      }
    }

    _notifyConnectionState();
    notifyListeners();
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
    _reconnectAttempts = 0; // 手动重试重新计数
    _xiaomiGuidePending = false;
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
    return _scanner.selectPreferredDevice(savedDeviceId: _savedDeviceId);
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
    _autoReconnect = false;
    _autoConnectEnabled = false;
    _reconnectAttempts = 0;
    _connecting = false;
    final deviceId = _connectedDeviceId;

    // Delegate to connection service
    await _connectionService.disconnect();

    // Clean up local state
    _hrSubscribed = false;
    _connectedDeviceId = null;
    _connectedDeviceName = null;
    _rssi = null;
    _heartRate = null;
    _publishedHeartRate = null;
    _lastUpdated = null;
    _lastHrSeenAt = null;
    _prevHeartRateAt = null;
    _savedDeviceId = null;
    await _prefs?.remove('last_device_id');
    _savedDeviceName = null;
    await _prefs?.remove('last_device_name');
    _connectionState = AdapterConnectionState.disconnected;
    _connectedAt = null;

    _syncHrOnline(now: DateTime.now(), forceOsc: true);
    _notifyConnectionState();
    notifyListeners();

    // Release per-device adapter state (matters for rotating-MAC devices).
    if (deviceId != null) {
      _bleAdapter.cleanupDevice(deviceId);
    }

    await Future.delayed(const Duration(milliseconds: 300));
    await restartScan();
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
    if (_connectionState == AdapterConnectionState.connected || _connecting) {
      return;
    }

    // 连续失败达到上限后停止自动重连，等待用户手动操作，避免无限连接风暴
    final delay = reconnectDelayFor(
      _reconnectAttempts + 1,
      immediate: immediate,
    );
    if (delay == null) {
      _log('auto reconnect gave up after $_reconnectAttempts attempts');
      _autoReconnect = false;
      _setStatus('自动重连失败，请手动选择设备重试', force: true);
      notifyListeners();
      return;
    }

    // Logic: find target device ID and try to connect.
    final targetId = _savedDeviceId;
    if (targetId == null) return;

    _reconnectAttempts++;
    final delaySeconds = delay.inSeconds;

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

      NearbyDevice? nearby = nearbyDevices
          .where((d) => d.id == targetId)
          .firstOrNull;

      // Xiaomi/Redmi wearables rotate their MAC address, so the saved id
      // stops matching. Fall back to the saved name; for Xiaomi devices pick
      // the strongest signal when multiple advertise the same name.
      final savedName = _savedDeviceName?.trim() ?? '';
      if (nearby == null && savedName.isNotEmpty) {
        final matches = nearbyDevices
            .where(
              (d) =>
                  d.connectable &&
                  d.name.trim().toLowerCase() == savedName.toLowerCase(),
            )
            .toList();
        if (matches.length == 1) {
          nearby = matches.first;
        } else if (matches.length > 1 && BleScanner.isXiaomiDevice(savedName)) {
          matches.sort((a, b) => b.rssi.compareTo(a.rssi));
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

  /// Backoff delay before the Nth reconnect attempt, or null when auto
  /// reconnect should give up (consecutive failures reached the cap).
  @visibleForTesting
  static Duration? reconnectDelayFor(int attempt, {required bool immediate}) {
    if (attempt >= _maxReconnectAttempts) return null;
    if (immediate) return Duration.zero;
    if (attempt > 5) return const Duration(seconds: 30);
    if (attempt > 3) return const Duration(seconds: 10);
    return Duration(seconds: 3 * attempt);
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
    final percent = _percentFor(bpm);
    final connected = isConnected;
    _publishedHeartRate = bpm;

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
          bpm: heartRate,
          lastUpdated: _lastUpdated,
        ),
      );
    } else {
      unawaited(_notificationService.showDisconnected(status: _status));
    }
  }

  Future<void> _sendPushPayload(Map<String, dynamic> payload) async {
    final bpm = payload['heartRate'] as int?;
    final timestamp = DateTime.tryParse(payload['timestamp'] as String? ?? '');
    final percent = payload['percent'] as double?;
    if (bpm == null || timestamp == null) return;

    await _pushCoordinator.sendHeartRate(
      bpm: bpm,
      percent: percent,
      timestamp: timestamp,
    );
  }

  Future<void> _sendOscConnectedIfNeeded(
    bool connected, {
    bool force = false,
  }) async {
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

  void _handleOscStatusChanged(OscStatus status) {
    notifyListeners();
  }

  /// Called by the connection service when service discovery finished but no
  /// standard heart rate service (0x180D) was found. Xiaomi/Redmi wearables
  /// only expose it after "Heart Rate Broadcast" is enabled on the device.
  void _handleHrServiceMissing(String deviceName) {
    _log('hr service missing on device: $deviceName');
    if (BleScanner.isXiaomiDevice(deviceName)) {
      if (_xiaomiGuidePending) return;
      _xiaomiGuidePending = true;
      _setStatus('未找到心率服务，请开启手表的「心率广播」', force: true);
      notifyListeners();
    } else {
      _setStatus('设备未提供标准心率服务', force: true);
      notifyListeners();
    }
  }

  /// Called by the UI after the guidance dialog has been shown.
  void dismissXiaomiGuide() {
    _xiaomiGuidePending = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _log('dispose');
    _scanResultsSub?.cancel();
    _adapterStateSub?.cancel();
    _reconnectTimer?.cancel();
    _scanUiHoldTimer?.cancel();
    _connectionService.dispose();

    _scanLoopTimer?.cancel();
    _uiNotifyTimer?.cancel();
    _pushCoordinator.dispose();
    _bleAdapter.dispose();
    unawaited(_notificationService.stop());
    super.dispose();
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

  double? _percentFor(int? bpm) {
    if (bpm == null || _settings.maxHeartRate <= 0) return null;
    final percent = bpm / _settings.maxHeartRate;
    return percent.clamp(0, 1).toDouble();
  }
}
