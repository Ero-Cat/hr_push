import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io' show Platform, RawDatagramSocket, InternetAddress;

import 'package:flutter/foundation.dart';
import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/io.dart';

import 'app_log.dart';
import 'hr_notification_service.dart';

final Guid _heartRateService = Guid('0000180d-0000-1000-8000-00805f9b34fb');
final Guid _heartRateMeasurement = Guid('00002a37-0000-1000-8000-00805f9b34fb');

class NearbyDevice {
  NearbyDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.connectable,
    required this.device,
    required this.lastSeen,
  });

  final String id;
  final String name;
  int rssi;
  bool connectable;
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
    required this.oscChatboxEnabled,
    required this.oscChatboxTemplate,
    required this.maxHeartRate,
    required this.updateIntervalMs,
    required this.logEnabled,
    required this.mqttBroker,
    required this.mqttPort,
    required this.mqttTopic,
    required this.mqttUsername,
    required this.mqttPassword,
    required this.mqttClientId,
  });

  final String pushEndpoint;
  final String oscAddress;
  final String oscHrConnectedPath;
  final String oscHrValuePath;
  final String oscHrPercentPath;
  final bool oscChatboxEnabled;
  final String oscChatboxTemplate;
  final int maxHeartRate;
  final int updateIntervalMs;
  final bool logEnabled;
  final String mqttBroker;
  final int mqttPort;
  final String mqttTopic;
  final String mqttUsername;
  final String mqttPassword;
  final String mqttClientId;

  static const _defaultPushEndpoint = '';
  static const _defaultOscAddress = '';
  static const _defaultHrConnectedPath = '/avatar/parameters/hr_connected';
  static const _defaultHrValuePath = '/avatar/parameters/hr_val';
  static const _defaultHrPercentPath = '/avatar/parameters/hr_percent';
  static const _defaultOscChatboxEnabled = false;
  static const _defaultOscChatboxTemplate = '💓{hr}';
  static const _defaultMaxHeartRate = 200;
  static const _defaultUpdateIntervalMs = 1000;
  static const _defaultLogEnabled = false;
  static const _defaultMqttBroker = '';
  static const _defaultMqttPort = 1883;
  static const _defaultMqttTopic = 'hr_push';
  static const _defaultMqttUsername = '';
  static const _defaultMqttPassword = '';
  static const _defaultMqttClientId = '';

  static const _kPushEndpointKey = 'cfg_push_endpoint';
  static const _kOscAddressKey = 'cfg_osc_address';
  static const _kOscConnectedKey = 'cfg_osc_connected_path';
  static const _kOscValueKey = 'cfg_osc_value_path';
  static const _kOscPercentKey = 'cfg_osc_percent_path';
  static const _kOscChatboxEnabledKey = 'cfg_osc_chatbox_enabled';
  static const _kOscChatboxTemplateKey = 'cfg_osc_chatbox_template';
  static const _kMaxHeartRateKey = 'cfg_max_heart_rate';
  static const _kUpdateIntervalKey = 'cfg_update_interval_ms';
  static const _kLogEnabledKey = 'cfg_log_enabled';
  static const _kMqttBrokerKey = 'cfg_mqtt_broker';
  static const _kMqttPortKey = 'cfg_mqtt_port';
  static const _kMqttTopicKey = 'cfg_mqtt_topic';
  static const _kMqttUsernameKey = 'cfg_mqtt_username';
  static const _kMqttPasswordKey = 'cfg_mqtt_password';
  static const _kMqttClientIdKey = 'cfg_mqtt_client_id';

  factory HeartRateSettings.defaults() {
    return const HeartRateSettings(
      pushEndpoint: _defaultPushEndpoint,
      oscAddress: _defaultOscAddress,
      oscHrConnectedPath: _defaultHrConnectedPath,
      oscHrValuePath: _defaultHrValuePath,
      oscHrPercentPath: _defaultHrPercentPath,
      oscChatboxEnabled: _defaultOscChatboxEnabled,
      oscChatboxTemplate: _defaultOscChatboxTemplate,
      maxHeartRate: _defaultMaxHeartRate,
      updateIntervalMs: _defaultUpdateIntervalMs,
      logEnabled: _defaultLogEnabled,
      mqttBroker: _defaultMqttBroker,
      mqttPort: _defaultMqttPort,
      mqttTopic: _defaultMqttTopic,
      mqttUsername: _defaultMqttUsername,
      mqttPassword: _defaultMqttPassword,
      mqttClientId: _defaultMqttClientId,
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
      oscChatboxEnabled:
          prefs.getBool(_kOscChatboxEnabledKey) ?? _defaultOscChatboxEnabled,
      oscChatboxTemplate:
          prefs.getString(_kOscChatboxTemplateKey) ??
          _defaultOscChatboxTemplate,
      maxHeartRate: prefs.getInt(_kMaxHeartRateKey) ?? _defaultMaxHeartRate,
      updateIntervalMs:
          prefs.getInt(_kUpdateIntervalKey) ?? _defaultUpdateIntervalMs,
      logEnabled: prefs.getBool(_kLogEnabledKey) ?? _defaultLogEnabled,
      mqttBroker: prefs.getString(_kMqttBrokerKey) ?? _defaultMqttBroker,
      mqttPort: prefs.getInt(_kMqttPortKey) ?? _defaultMqttPort,
      mqttTopic: prefs.getString(_kMqttTopicKey) ?? _defaultMqttTopic,
      mqttUsername: prefs.getString(_kMqttUsernameKey) ?? _defaultMqttUsername,
      mqttPassword: prefs.getString(_kMqttPasswordKey) ?? _defaultMqttPassword,
      mqttClientId: prefs.getString(_kMqttClientIdKey) ?? _defaultMqttClientId,
    );
  }

  Future<void> save(SharedPreferences? prefs) async {
    if (prefs == null) return;
    await prefs.setString(_kPushEndpointKey, pushEndpoint);
    await prefs.setString(_kOscAddressKey, oscAddress);
    await prefs.setString(_kOscConnectedKey, oscHrConnectedPath);
    await prefs.setString(_kOscValueKey, oscHrValuePath);
    await prefs.setString(_kOscPercentKey, oscHrPercentPath);
    await prefs.setBool(_kOscChatboxEnabledKey, oscChatboxEnabled);
    await prefs.setString(_kOscChatboxTemplateKey, oscChatboxTemplate);
    await prefs.setInt(_kMaxHeartRateKey, maxHeartRate);
    await prefs.setInt(_kUpdateIntervalKey, updateIntervalMs);
    await prefs.setBool(_kLogEnabledKey, logEnabled);
    await prefs.setString(_kMqttBrokerKey, mqttBroker);
    await prefs.setInt(_kMqttPortKey, mqttPort);
    await prefs.setString(_kMqttTopicKey, mqttTopic);
    await prefs.setString(_kMqttUsernameKey, mqttUsername);
    await prefs.setString(_kMqttPasswordKey, mqttPassword);
    await prefs.setString(_kMqttClientIdKey, mqttClientId);
  }

  HeartRateSettings copyWith({
    String? pushEndpoint,
    String? oscAddress,
    String? oscHrConnectedPath,
    String? oscHrValuePath,
    String? oscHrPercentPath,
    bool? oscChatboxEnabled,
    String? oscChatboxTemplate,
    int? maxHeartRate,
    int? updateIntervalMs,
    bool? logEnabled,
    String? mqttBroker,
    int? mqttPort,
    String? mqttTopic,
    String? mqttUsername,
    String? mqttPassword,
    String? mqttClientId,
  }) {
    return HeartRateSettings(
      pushEndpoint: pushEndpoint ?? this.pushEndpoint,
      oscAddress: oscAddress ?? this.oscAddress,
      oscHrConnectedPath: oscHrConnectedPath ?? this.oscHrConnectedPath,
      oscHrValuePath: oscHrValuePath ?? this.oscHrValuePath,
      oscHrPercentPath: oscHrPercentPath ?? this.oscHrPercentPath,
      oscChatboxEnabled: oscChatboxEnabled ?? this.oscChatboxEnabled,
      oscChatboxTemplate: oscChatboxTemplate ?? this.oscChatboxTemplate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      updateIntervalMs: updateIntervalMs ?? this.updateIntervalMs,
      logEnabled: logEnabled ?? this.logEnabled,
      mqttBroker: mqttBroker ?? this.mqttBroker,
      mqttPort: mqttPort ?? this.mqttPort,
      mqttTopic: mqttTopic ?? this.mqttTopic,
      mqttUsername: mqttUsername ?? this.mqttUsername,
      mqttPassword: mqttPassword ?? this.mqttPassword,
      mqttClientId: mqttClientId ?? this.mqttClientId,
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
  MqttServerClient? _mqttClient;
  bool _mqttConnecting = false;
  bool _mqttConnected = false;

  Timer? _reconnectTimer;
  Timer? _scanUiHoldTimer;
  Timer? _resubscribeTimer;
  Timer? _rssiPollTimer;
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
  String? _lastOscHrConnectedKey;
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
  BluetoothAdapterState _adapterState = BluetoothAdapterState.unknown;
  DateTime? _connectedAt;
  DateTime? _lastChatboxSentAt;
  String? _lastChatboxMessage;

  final List<NearbyDevice> _nearby = [];
  DateTime? _lastStatusChange;
  DateTime? _lastScanResultAt;

  // 扫描周期 1000ms
  static const Duration _scanInterval = Duration(milliseconds: 1000);
  static const Duration _uiNotifyInterval = Duration(milliseconds: 200);
  // 为避免按钮闪烁，至少保持 3s 的“扫描中”显示
  static const Duration _scanUiMinVisible = Duration(seconds: 3);
  static const Duration _scanStaleThreshold = Duration(seconds: 4);
  static const Duration _nearbyTtl = Duration(seconds: 8);
  static const Duration _reconnectBaseDelay = Duration(seconds: 2);
  static const Duration _reconnectMaxDelay = Duration(seconds: 30);
  static const Duration _hrStaleThreshold = Duration(seconds: 6);
  static const Duration _hrInitialOnlineGrace = Duration(seconds: 3);
  static const Duration _oscChatboxMinInterval = Duration(seconds: 2);
  DateTime? _prevHeartRateAt;
  DateTime? _lastActionAt;
  static const Duration _actionCooldown = Duration(seconds: 2);
  Timer? _scanLoopTimer;
  bool _scanLoopStarting = false;
  int _reconnectAttempts = 0;

  static const Duration _gattStableDelay = Duration(milliseconds: 600);
  static const Duration _gattStableDelayWindows = Duration(milliseconds: 1200);

  UnmodifiableListView<NearbyDevice> get nearbyDevices =>
      UnmodifiableListView(_nearby);

  UnmodifiableListView<ScanResult> get debugScanResults =>
      UnmodifiableListView(_scanResults);

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
      _connectionState == BluetoothConnectionState.connected ? _rssi : null;
  int? get lastIntervalMs => _lastUpdated != null && _prevHeartRateAt != null
      ? _lastUpdated!.difference(_prevHeartRateAt!).inMilliseconds
      : null;
  String get status => _status;
  DateTime? get lastUpdated => _lastUpdated;
  String get connectedName {
    if (_connectionState != BluetoothConnectionState.connected) return '';
    return _connectedDevice?.platformName ?? '';
  }
  String? get activeDeviceId => _connectedDevice?.remoteId.str;

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

  @visibleForTesting
  static bool computeHrOnline({
    required bool userInitiatedDisconnect,
    required BluetoothAdapterState adapterState,
    required BluetoothConnectionState connectionState,
    required DateTime now,
    required DateTime? lastHeartRateAt,
    required DateTime? connectedAt,
    Duration hrFreshFor = _hrStaleThreshold,
    Duration initialGrace = _hrInitialOnlineGrace,
  }) {
    if (userInitiatedDisconnect) return false;
    if (adapterState != BluetoothAdapterState.on) return false;

    final isFresh =
        lastHeartRateAt != null &&
        now.difference(lastHeartRateAt) <= hrFreshFor;
    if (isFresh) return true;

    if (connectionState == BluetoothConnectionState.connected &&
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
      _adapterState = BluetoothAdapterState.off;
      notifyListeners();
      return;
    }

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

    _adapterStateSub = FlutterBluePlus.adapterState.listen((state) {
      _adapterState = state;
      if (state != BluetoothAdapterState.on) {
        _setStatus('请开启蓝牙');
      }
      _log('adapter state=$state');
      _syncHrOnline(now: DateTime.now(), forceOsc: true);
      notifyListeners();
    });

    _scanResultsSub = FlutterBluePlus.scanResults.listen(_handleScanResults);
    _isScanningSub = FlutterBluePlus.isScanning.listen((scanning) {
      _isScanning = scanning;
      _setUiScanning(scanning);
      _log('scan state=${scanning ? 'on' : 'off'}');
    });

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

    if (!await FlutterBluePlus.isSupported) {
      _setStatus('此设备不支持蓝牙');
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

      // 弹系统对话框打开蓝牙
      await FlutterBluePlus.turnOn();
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
    if (_connectionState != BluetoothConnectionState.connected) return;

    final last = _lastUpdated ?? _prevHeartRateAt;
    if (last == null) return;

    // 若超过两倍心率失效阈值仍无数据，判定为掉线，主动重连（Windows 上常见）.
    if (now.difference(last) > _hrStaleThreshold * 2) {
      _log('stale connection, forcing reconnect');
      _setStatus('连接失活，自动重连...');
      _connectionState = BluetoothConnectionState.disconnected;
      _connectedAt = null;
      _stopRssiPolling();
      unawaited(() async {
        try {
          await _connectedDevice?.disconnect();
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
    if (_connectionState == BluetoothConnectionState.connected || _connecting) {
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
      _lastScanResultAt = DateTime.now();
      _setStatus('扫描附近设备...');
      _setUiScanning(true);
      notifyListeners();
      _log('scan start');
      await FlutterBluePlus.startScan(
        timeout: _scanInterval,
        // 一些腕表并不会在广播里声明心率服务, 所以不加 withServices 过滤
        continuousUpdates: true,
      );
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
    if (_connectionState == BluetoothConnectionState.connected || _connecting) {
      _log('restartScan skipped: connected/connecting');
      return;
    }
    await FlutterBluePlus.stopScan();
    _nearby.clear();
    notifyListeners();
    await _startScan();
  }

  void _handleScanResults(List<ScanResult> results) {
    final now = DateTime.now();
    if (results.isNotEmpty) {
      _lastScanResultAt = now;
    }
    for (final r in results) {
      if (_isLikelyPhoneOrPc(r)) continue;
      if (!_isWearableHeartRateCandidate(r)) continue;

      final name = r.advertisementData.advName.isNotEmpty
          ? r.advertisementData.advName
          : (r.device.platformName.isNotEmpty
                ? r.device.platformName
                : '未命名设备');

      final id = r.device.remoteId.str;
      // Windows 上设备长时间离线后，缓存的 BluetoothDevice 可能失效。
      // 如果扫描到同 ID 的新实例且当前未连接，刷新引用以便后续重连使用最新句柄。
      if (_connectionState != BluetoothConnectionState.connected &&
          _connectedDevice?.remoteId.str == id &&
          !identical(_connectedDevice, r.device)) {
        _connectedDevice = r.device;
      }

      final existingIndex = _nearby.indexWhere((d) => d.id == id);
      if (existingIndex >= 0) {
        _nearby[existingIndex]
          ..rssi = r.rssi
          ..connectable = r.advertisementData.connectable
          ..lastSeen = now;
      } else {
        _nearby.add(
          NearbyDevice(
            id: id,
            name: name,
            rssi: r.rssi,
            connectable: r.advertisementData.connectable,
            device: r.device,
            lastSeen: now,
          ),
        );
        _log(
          'scan found: $name ($id) rssi=${r.rssi} connectable=${r.advertisementData.connectable}',
        );
      }

      _updateBroadcastHeartRate(r);

      if (_userInitiatedDisconnect) continue;

      if (_autoConnectEnabled &&
          _shouldPrefer(r) &&
          (_savedDeviceId == null || _savedDeviceId == id) &&
          _connectionState != BluetoothConnectionState.connected &&
          // 广播模式设备通常不可连接，避免无意义的连接尝试
          r.advertisementData.connectable) {
        _pendingConnectName = name;
        _log('auto connect: $name ($id)');
        _connectTo(r.device);
      }
    }

    _pruneNearby(now);
    _nearby.sort((a, b) => b.rssi.compareTo(a.rssi));
    _notifyUi();
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
    _log('hr rx broadcast: bpm=$bpm rssi=${r.rssi} name=${r.device.platformName}');
    _prevHeartRateAt = _lastUpdated;
    _heartRate = bpm;
    _rssi = r.rssi;
    _lastUpdated = now;
    _lastHrSeenAt = now;
    _syncHrOnline(now: now);
    final shouldPublish = _shouldPublishNow(now);
    if (!shouldPublish) return;

    _lastPublished = now;
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

  /// Detects if the device is a Xiaomi/Mi Band device which may require
  /// special handling (e.g., pairing before HR service access)
  bool _isXiaomiDevice(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.contains('xiaomi') ||
        lowerName.contains('小米') ||
        lowerName.contains('mi band') ||
        lowerName.contains('mi smart band') ||
        lowerName.contains('miband') ||
        lowerName.contains('手环');
  }

  bool _isWearableHeartRateCandidate(ScanResult r) {

    final hasHeartRateService = r.advertisementData.serviceUuids
        .map((e) => e.str.toLowerCase())
        .any((id) => id.contains('180d'));
    final hasHeartRateServiceData = r.advertisementData.serviceData.containsKey(
      _heartRateService,
    );

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
        name.contains('mi smart band') ||
        name.contains('xiaomi') ||
        name.contains('小米') ||  // Xiaomi in Chinese
        name.contains('miband') ||
        name.contains('mi band') ||
        name.contains('手环') ||  // "band/bracelet" in Chinese
        name.contains('watch');

    return hasHeartRateService || hasHeartRateServiceData || likelyHrWearable;
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
      'honor',
      'oneplus',
      'oppo',
      'vivo',
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

    const wearableKeywords = [
      'band',
      'watch',
      'hrm',
      'heart',
      'fit',
      'wear',
      'miband',
      'mi band',
      'smart band',
      'smartband',
      '小米',  // Xiaomi in Chinese
      '手环',  // "band/bracelet" in Chinese
      '手表',  // "watch" in Chinese
    ];


    if (wearableKeywords.any(name.contains)) {
      return false;
    }
    return phoneKeywords.any(name.contains) || pcKeywords.any(name.contains);
  }

  Future<void> _connectTo(BluetoothDevice device) async {
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
    _connectedDevice = device;
    _userInitiatedDisconnect = false;
    _connectionState = BluetoothConnectionState.disconnected;
    final label = (_pendingConnectName?.trim().isNotEmpty ?? false)
        ? _pendingConnectName!.trim()
        : device.platformName;
    _setStatus('正在连接 $label...');
    notifyListeners();
    _log('connect start: ${device.remoteId.str} name=$label');

    await FlutterBluePlus.stopScan();

    await _deviceStateSub?.cancel();
    _deviceStateSub = device.connectionState.listen((state) {
      _connectionState = state;
      if (state == BluetoothConnectionState.connected) {
        _connectedAt = DateTime.now();
        _setStatus('已连接', force: true);
      }
      if (state == BluetoothConnectionState.disconnected) {
        _connectedAt = null;
        _heartRateSub?.cancel();
        _hrSubscribed = false;
        _heartRate = null;
        _rssi = null;
        _lastUpdated = null;
        _prevHeartRateAt = null;
        _stopRssiPolling();
        _autoConnectEnabled = !_userInitiatedDisconnect;
        if (_userInitiatedDisconnect) {
          _autoReconnect = false;
        }
        if (_userInitiatedDisconnect) {
          _connectedDevice = null;
          _deviceStateSub?.cancel();
        }
      }
      _log('connection state=$state');
      _notifyConnectionState();
      notifyListeners();
      if (state == BluetoothConnectionState.disconnected &&
          !_userInitiatedDisconnect) {
        _reconnectAttempts = 0; // 重置退避，优先立即重连
        _scheduleReconnect(immediate: true);
      }
    });

    try {
      await device
          .connect(timeout: const Duration(seconds: 10), autoConnect: false)
          .timeout(const Duration(seconds: 10));
      _setStatus('已连接，订阅心率中...', force: true);
      try {
        _rssi = await device.readRssi();
      } catch (_) {
        _rssi = null;
      }
      _connectionState = BluetoothConnectionState.connected;
      _connectedAt = DateTime.now();
      _reconnectTimer?.cancel();
      _reconnectAttempts = 0;
      notifyListeners();
      final name = (_pendingConnectName?.trim().isNotEmpty ?? false)
          ? _pendingConnectName!.trim()
          : device.platformName.trim();
      _pendingConnectName = null;
      _rememberLastDevice(device.remoteId.str, name);
      _startRssiPolling(device);
      await _subscribeHeartRate(device);
    } catch (e) {
      _log('connect failed', error: e);
      _setStatus(_formatErrorForStatus(e, fallback: '连接失败'), force: true);
      _connectionState = BluetoothConnectionState.disconnected;
      _connectedAt = null;
      notifyListeners();
      await restartScan();
    } finally {
      _connecting = false;
      if (_connectionState != BluetoothConnectionState.connected) {
        _pendingConnectName = null;
      }
      if (_connectionState != BluetoothConnectionState.connected &&
          !_userInitiatedDisconnect &&
          _autoReconnect &&
          _connectedDevice != null &&
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
    await _connectTo(target.device);
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
      await _connectTo(target.device);
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
    BluetoothDevice device, {
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
      if (Platform.isWindows && _isXiaomiDevice(device.platformName)) {
        _log('Xiaomi device detected, checking bond status');
        try {
          // Check if we need to initiate pairing
          // Note: flutter_blue_plus_windows uses createBond() for pairing
          _setStatus('正在配对...', force: true);
          notifyListeners();
          await device.createBond();
          _log('Pairing initiated/confirmed for Xiaomi device');
          // Give some time for pairing to complete and services to become available
          await Future.delayed(const Duration(milliseconds: 1500));
        } catch (e) {
          _log('Pairing attempt failed (may already be paired)', error: e);
          // Continue anyway - device may already be paired
        }
      }

      final services = await device.discoverServices();
      
      // Debug log all services to see what the device actually exposes
      final serviceUuids = services.map((s) => s.uuid.str).join(', ');
      _log('discovered services: [$serviceUuids]');


      bool foundHr = false;
      for (final service in services) {
        if (service.uuid != _heartRateService) continue;
        foundHr = true;
        for (final c in service.characteristics) {
          if (c.uuid == _heartRateMeasurement) {
            final ok = await _enableHrNotifications(c);
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
      _scheduleResubscribe(device, attempt: attempt + 1);
    } catch (e) {
      _log('subscribe hr failed', error: e);
      // 部分设备刚连接时立即写 CCCD/READ 可能报错，延迟重试一次
      if (e is PlatformException && attempt < 1) {
        _setStatus('订阅心率重试中...', force: true);
        notifyListeners();
        await Future.delayed(const Duration(milliseconds: 800));
        if (_connectedDevice == device &&
            _connectionState == BluetoothConnectionState.connected) {
          await _subscribeHeartRate(device, attempt: attempt + 1);
        }
        return;
      }

      _setStatus(_formatErrorForStatus(e, fallback: '订阅心率失败'), force: true);
      notifyListeners();
      _scheduleResubscribe(device, attempt: attempt + 1);
    }
  }

  void _scheduleResubscribe(BluetoothDevice device, {required int attempt}) {
    if (attempt > 3) {
      // 多次失败后主动断开并重连，避免 Windows 下状态不一致
      _forceReconnect(reason: 'subscribe failed');
      return;
    }

    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(const Duration(seconds: 2), () {
      if (_connectedDevice == device &&
          _connectionState == BluetoothConnectionState.connected) {
        _subscribeHeartRate(device, attempt: attempt);
      }
    });
  }

  Future<bool> _enableHrNotifications(BluetoothCharacteristic c) async {
    const attempts = 2;
    for (var i = 0; i < attempts; i++) {
      try {
        await c.setNotifyValue(true);
        _heartRateSub = c.lastValueStream.listen(_handleHeartRateData);
        try {
          await c.read();
        } catch (e) {
          // 部分设备读取可能失败，但通知已经开启，继续使用通知数据
          _log('hr read failed (ignored)', error: e);
        }
        _resubscribeTimer?.cancel();
        _hrSubscribed = true;
        _missingHrNotified = false;
        _setStatus('已连接', force: true);
        return true;
      } catch (e) {
        // 如果已经开启通知, 忽略重复错误
        if (e is PlatformException && e.code == 'setNotifyValue') {
          try {
            _heartRateSub = c.lastValueStream.listen(_handleHeartRateData);
            _resubscribeTimer?.cancel();
            _hrSubscribed = true;
            _missingHrNotified = false;
            _setStatus('已连接', force: true);
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

  void _startRssiPolling(BluetoothDevice device) {
    _rssiPollTimer?.cancel();
    final ms = _settings.updateIntervalMs;
    if (ms <= 0) return;
    final interval = Duration(milliseconds: ms);
    _rssiPollTimer = Timer.periodic(interval, (_) {
      unawaited(_pollRssi(device));
    });
  }

  Future<void> _pollRssi(BluetoothDevice device) async {
    if (_connectionState != BluetoothConnectionState.connected ||
        _connectedDevice != device ||
        _userInitiatedDisconnect ||
        _connecting) {
      return;
    }
    try {
      final value = await device.readRssi();
      if (_connectionState != BluetoothConnectionState.connected ||
          _connectedDevice != device) {
        return;
      }
      _rssi = value;
      _notifyUi();
    } catch (_) {
      // 部分平台读 RSSI 可能失败，忽略即可
    }
  }

  void _stopRssiPolling() {
    _rssiPollTimer?.cancel();
    _rssiPollTimer = null;
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
    _stopRssiPolling();
    _autoReconnect = false; // 手动断开后不再自动重连
    _autoConnectEnabled = false;
    _reconnectAttempts = 0;
    _connecting = false;
    _resubscribeTimer?.cancel();
    _setStatus('断开中...');
    _syncHrOnline(now: DateTime.now(), forceOsc: true);
    try {
      await _connectedDevice?.disconnect();
      // 部分平台在“连接中”瞬间按断开可能无事件回调，强制置为断开态
      _connectionState = BluetoothConnectionState.disconnected;
      _connectedAt = null;
    } finally {
      await _deviceStateSub?.cancel();
      await _heartRateSub?.cancel();
      _hrSubscribed = false;
      _connectedDevice = null;
      _rssi = null;
      _heartRate = null;
      _lastUpdated = null;
      _lastHrSeenAt = null;
      _prevHeartRateAt = null;
      _savedDeviceId = null;
      await _prefs?.remove('last_device_id');
      _savedDeviceName = null;
      await _prefs?.remove('last_device_name');
      _connectionState = BluetoothConnectionState.disconnected;
      _connectedAt = null;
      _setStatus('已断开', force: true);
      _notifyConnectionState();
      notifyListeners();
      // 某些设备断开后需要短暂间隔再扫描，避免“设备繁忙”
      await Future.delayed(const Duration(milliseconds: 300));
      await restartScan();
    }
  }

  Duration _computeReconnectDelay() {
    final factor = 1 << _reconnectAttempts;
    final ms = (_reconnectBaseDelay.inMilliseconds * factor)
        .clamp(
          _reconnectBaseDelay.inMilliseconds,
          _reconnectMaxDelay.inMilliseconds,
        )
        .toInt();
    return Duration(milliseconds: ms);
  }

  Future<void> _ensureScanAlive() async {
    if (_connectionState == BluetoothConnectionState.connected || _connecting) {
      return;
    }
    final now = DateTime.now();
    final scanStale =
        _isScanning &&
        _lastScanResultAt != null &&
        now.difference(_lastScanResultAt!) > _scanStaleThreshold;
    if (_isScanning && !scanStale) return;
    await FlutterBluePlus.stopScan();
    await _startScan();
  }

  void _scheduleReconnect({bool immediate = false}) {
    if (!_isBleSupportedPlatform) return;
    if (!_autoReconnect || _connectedDevice == null) return;
    if (_userInitiatedDisconnect) return;
    if (_connectionState == BluetoothConnectionState.connected || _connecting) {
      return;
    }
    _reconnectTimer?.cancel();
    final delay = immediate ? Duration.zero : _computeReconnectDelay();
    if (!immediate) {
      _reconnectAttempts = (_reconnectAttempts + 1).clamp(0, 10).toInt();
    }

    _reconnectTimer = Timer(delay, () async {
      final target = _connectedDevice;
      if (target == null || !_autoReconnect) return;

      if (_adapterState != BluetoothAdapterState.on) {
        _setStatus('等待蓝牙开启...');
        notifyListeners();
        _scheduleReconnect();
        return;
      }

      await _ensureScanAlive();

      NearbyDevice? nearby;
      for (final d in _nearby) {
        if (d.id == target.remoteId.str) {
          nearby = d;
          break;
        }
      }

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

      final deviceForReconnect = nearby.device;
      if (!identical(deviceForReconnect, _connectedDevice)) {
        _connectedDevice = deviceForReconnect;
      }

      _pendingConnectName = nearby.name;
      _setStatus('自动重连中...');
      notifyListeners();
      _log('auto reconnect: ${nearby.name} (${nearby.id})');
      // Windows 偶发保留陈旧连接句柄，确保重连使用扫描到的最新实例。
      await _connectTo(deviceForReconnect);
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
    if (_connectedDevice == null) return;
    _setStatus('订阅心率失败，正在重连...', force: true);
    notifyListeners();

    try {
      await _connectedDevice?.disconnect();
    } catch (e) {
      _log('disconnect during force reconnect failed', error: e);
    }

    _connectionState = BluetoothConnectionState.disconnected;
    _connectedAt = null;
    _stopRssiPolling();
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
      'device': _connectedDevice?.platformName,
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
        deviceName: _connectedDevice?.platformName ?? '',
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
      'device': _connectedDevice?.platformName,
      'timestamp': DateTime.now().toIso8601String(),
    };
    _log('push event=connection connected=$connected');

    unawaited(_sendPushPayload(payload));
    if (connected) {
      unawaited(
        _notificationService.showConnected(
          deviceName: _connectedDevice?.platformName ?? '',
          bpm: _heartRate,
          lastUpdated: _lastUpdated,
        ),
      );
    } else {
      unawaited(_notificationService.showDisconnected(status: _status));
    }
  }

  Future<void> _sendPushPayload(Map<String, dynamic> payload) async {
    final endpoint = _settings.pushEndpoint.trim();
    if (endpoint.isNotEmpty) {
      final uri = Uri.tryParse(endpoint);
      if (uri != null) {
        if (uri.scheme.startsWith('ws')) {
          _log('push ws start: ${_formatEndpoint(uri)}');
          await _sendWs(uri, payload);
        } else if (uri.scheme.startsWith('http')) {
          _log('push http start: ${_formatEndpoint(uri)}');
          await _sendHttp(uri, payload);
        }
      } else {
        _log('push endpoint invalid: $endpoint');
      }
    }

    await _sendMqtt(payload);
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
      _log('push http ok: ${_formatEndpoint(uri)}');
    } catch (e) {
      _log('push http failed: ${_formatEndpoint(uri)}', error: e);
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
            _log('push ws error: ${_formatEndpoint(uri)}');
            _wsChannel = null;
          },
          onDone: () {
            _log('push ws closed: ${_formatEndpoint(uri)}');
            _wsChannel = null;
          },
        );
        _log('push ws connected: ${_formatEndpoint(uri)}');
      } catch (e) {
        _log('push ws connect failed: ${_formatEndpoint(uri)}', error: e);
        _wsChannel = null;
      } finally {
        _wsConnecting = false;
      }
    }

    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode(payload));
        _log('push ws sent: ${_formatEndpoint(uri)}');
      } catch (_) {}
    }
  }

  Future<void> _sendMqtt(Map<String, dynamic> payload) async {
    final broker = _settings.mqttBroker.trim();
    final topic = _settings.mqttTopic.trim();
    if (broker.isEmpty || topic.isEmpty) return;

    await _ensureMqttConnected();
    final client = _mqttClient;
    if (client == null || !_mqttConnected) return;

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      _log('push mqtt published: $topic');
    } catch (e) {
      _log('push mqtt publish failed: $topic', error: e);
      _mqttConnected = false;
      _mqttClient?.disconnect();
      _mqttClient = null;
    }
  }

  Future<void> _ensureMqttConnected() async {
    if (_mqttConnected && _mqttClient != null) return;
    if (_mqttConnecting) return;

    _mqttConnecting = true;
    try {
      final broker = _settings.mqttBroker.trim();
      if (broker.isEmpty) return;
      var host = broker;
      var port = _settings.mqttPort > 0
          ? _settings.mqttPort
          : HeartRateSettings.defaults().mqttPort;
      if (broker.contains('://')) {
        final uri = Uri.tryParse(broker);
        if (uri != null && uri.host.isNotEmpty) {
          host = uri.host;
          if (_settings.mqttPort <= 0 && uri.port > 0) {
            port = uri.port;
          }
        }
      }
      final username = _settings.mqttUsername.trim();
      final password = _settings.mqttPassword;
      final rawClientId = _settings.mqttClientId.trim();
      final clientId = rawClientId.isNotEmpty
          ? rawClientId
          : 'hr_push_${DateTime.now().millisecondsSinceEpoch}';

      _log('push mqtt connecting: $host:$port clientId=$clientId');
      final client = MqttServerClient(host, clientId)
        ..port = port
        ..keepAlivePeriod = 20
        ..logging(on: false)
        ..onDisconnected = () {
          _log('push mqtt disconnected: $host:$port');
          _mqttConnected = false;
          _mqttClient = null;
        };

      final connMess = MqttConnectMessage()
          .withClientIdentifier(clientId)
          .withWillQos(MqttQos.atLeastOnce)
          .startClean();

      client.connectionMessage = connMess;

      try {
        await client.connect(
          username.isEmpty ? null : username,
          username.isEmpty ? null : password,
        );
      } catch (e) {
        _log('push mqtt connect failed: $host:$port', error: e);
        client.disconnect();
        return;
      }

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _mqttClient = client;
        _mqttConnected = true;
        _log('push mqtt connected: $host:$port');
      } else {
        client.disconnect();
      }
    } finally {
      _mqttConnecting = false;
    }
  }

  Future<void> _sendOscConnectedIfNeeded(
    bool connected, {
    bool force = false,
  }) async {
    final key =
        '${_settings.oscAddress.trim()}|${_settings.oscHrConnectedPath}|$connected';
    if (!force && _lastOscHrConnectedKey == key) return;

    final ok = await _sendOscMessage(_settings.oscHrConnectedPath, connected);
    if (ok) {
      _lastOscHrConnectedKey = key;
    }
  }

  Future<void> _sendOscHeartRate(int bpm, double? percent) async {
    await _sendOscMessage(_settings.oscHrValuePath, bpm);
    if (percent != null) {
      await _sendOscMessage(_settings.oscHrPercentPath, percent);
    }
  }

  Future<void> _sendOscChatboxIfNeeded(int bpm, double? percent) async {
    if (!_settings.oscChatboxEnabled) return;

    final text = _buildChatboxText(bpm, percent);
    if (text.trim().isEmpty) return;
    if (text == _lastChatboxMessage) return;

    final now = DateTime.now();
    if (_lastChatboxSentAt != null &&
        now.difference(_lastChatboxSentAt!) < _oscChatboxMinInterval) {
      return;
    }

    final ok = await _sendOscMessageWithArgs('/chatbox/input', [
      text,
      true, // send immediately
      false, // disable notification SFX
    ]);
    if (ok) {
      _lastChatboxSentAt = now;
      _lastChatboxMessage = text;
    }
  }

  String _buildChatboxText(int bpm, double? percent) {
    final template = _settings.oscChatboxTemplate.trim();
    if (template.isEmpty) return '';

    final percentValue = percent == null ? null : (percent * 100).round();
    var text = template
        .replaceAll('{hr}', bpm.toString())
        .replaceAll('{percent}', percentValue?.toString() ?? '');

    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text.split('\n');
    if (lines.length > 9) {
      text = lines.take(9).join('\n');
    }
    if (text.length > 144) {
      text = text.substring(0, 144);
    }

    return text;
  }

  Future<bool> _sendOscMessage(String address, Object value) async {
    final target = await _resolveOscTarget();
    if (target == null) {
      _log('push osc target invalid: $address');
      return false;
    }
    final socket = await _ensureOscSocket();
    if (socket == null) {
      _log('push osc socket unavailable: $address');
      return false;
    }

    final msg = _encodeOscMessage(address, [_oscArgFromValue(value)]);
    try {
      socket.send(msg, target.address, target.port);
      _log('push osc sent: $address -> ${target.address.address}:${target.port}');
      return true;
    } catch (_) {}
    _log('push osc failed: $address -> ${target.address.address}:${target.port}');
    return false;
  }

  Future<bool> _sendOscMessageWithArgs(
    String address,
    List<Object> args,
  ) async {
    final target = await _resolveOscTarget();
    if (target == null) {
      _log('push osc target invalid: $address');
      return false;
    }
    final socket = await _ensureOscSocket();
    if (socket == null) {
      _log('push osc socket unavailable: $address');
      return false;
    }

    final oscArgs = args.map(_oscArgFromValue).toList();
    final msg = _encodeOscMessage(address, oscArgs);
    try {
      socket.send(msg, target.address, target.port);
      _log('push osc sent: $address -> ${target.address.address}:${target.port}');
      return true;
    } catch (_) {}
    _log('push osc failed: $address -> ${target.address.address}:${target.port}');
    return false;
  }

  Future<_OscTarget?> _resolveOscTarget() async {
    final raw = _settings.oscAddress.trim();
    if (raw.isEmpty) return null;

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
    if (value is String) {
      return _OscArg('s', _oscString(value));
    }
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

    if (old.oscChatboxEnabled != value.oscChatboxEnabled ||
        old.oscChatboxTemplate != value.oscChatboxTemplate) {
      _lastChatboxMessage = null;
      _lastChatboxSentAt = null;
    }

    final oscConnectedChanged =
        old.oscAddress != value.oscAddress ||
        old.oscHrConnectedPath != value.oscHrConnectedPath;
    if (oscConnectedChanged) {
      _lastOscHrConnectedKey = null;
      _syncHrOnline(now: DateTime.now(), forceOsc: true);
    }

    final mqttChanged =
        old.mqttBroker != value.mqttBroker ||
        old.mqttPort != value.mqttPort ||
        old.mqttTopic != value.mqttTopic ||
        old.mqttUsername != value.mqttUsername ||
        old.mqttPassword != value.mqttPassword ||
        old.mqttClientId != value.mqttClientId;
    if (mqttChanged) {
      _mqttClient?.disconnect();
      _mqttClient = null;
      _mqttConnected = false;
      _mqttConnecting = false;
    }

    if (old.updateIntervalMs != value.updateIntervalMs &&
        _connectionState == BluetoothConnectionState.connected &&
        _connectedDevice != null) {
      if (value.updateIntervalMs <= 0) {
        _stopRssiPolling();
      } else {
        _startRssiPolling(_connectedDevice!);
      }
    }

    if (old.logEnabled != value.logEnabled) {
      AppLog.setEnabled(value.logEnabled);
    }
  }

  @override
  void dispose() {
    _log('dispose');
    _scanResultsSub?.cancel();
    _isScanningSub?.cancel();
    _deviceStateSub?.cancel();
    _heartRateSub?.cancel();
    _adapterStateSub?.cancel();
    _reconnectTimer?.cancel();
    _scanUiHoldTimer?.cancel();
    _resubscribeTimer?.cancel();
    _rssiPollTimer?.cancel();
    _scanLoopTimer?.cancel();
    _uiNotifyTimer?.cancel();
    _wsChannel?.sink.close();
    _oscSocket?.close();
    _mqttClient?.disconnect();
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

  String _formatEndpoint(Uri uri) {
    final port = uri.hasPort ? ':${uri.port}' : '';
    final path = uri.path.isEmpty ? '' : uri.path;
    return '${uri.scheme}://${uri.host}$port$path';
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
