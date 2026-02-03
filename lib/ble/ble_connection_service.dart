import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/services.dart';

import '../models/nearby_device.dart';
import 'ble_adapter.dart';
import 'ble_scanner.dart';

/// Callbacks for BLE connection events
typedef OnStatusChange = void Function(String status, {bool force});
typedef OnLog = void Function(String message, {Object? error});
typedef OnHeartRateData = void Function(Uint8List data);
typedef OnConnectionStateChange = void Function(AdapterConnectionState state);
typedef OnSubscriptionComplete = void Function(bool success);

/// Service for managing BLE device connections and heart rate subscriptions
class BleConnectionService {
  BleConnectionService({
    required BleAdapter adapter,
    required this.onLog,
    required this.onStatusChange,
    required this.onHeartRateData,
    required this.onConnectionStateChange,
  }) : _adapter = adapter;

  final BleAdapter _adapter;
  final OnLog onLog;
  final OnStatusChange onStatusChange;
  final OnHeartRateData onHeartRateData;
  final OnConnectionStateChange onConnectionStateChange;

  static const String _heartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';
  static const String _heartRateMeasurementUuid = '00002a37-0000-1000-8000-00805f9b34fb';
  static const Duration _gattStableDelay = Duration(milliseconds: 600);
  static const Duration _gattStableDelayWindows = Duration(milliseconds: 2000);

  StreamSubscription<AdapterConnectionState>? _connectionStateSub;
  StreamSubscription<Uint8List>? _heartRateSub;
  Timer? _resubscribeTimer;

  String? _connectedDeviceId;
  String? _connectedDeviceName;
  DateTime? _connectedAt;
  bool _connecting = false;
  bool _subscribed = false;
  bool _missingHrNotified = false;

  // Getters
  String? get connectedDeviceId => _connectedDeviceId;
  String? get connectedDeviceName => _connectedDeviceName;
  DateTime? get connectedAt => _connectedAt;
  bool get isConnecting => _connecting;
  bool get isSubscribed => _subscribed;

  /// Connect to a BLE device
  Future<bool> connect(String deviceId, {String? displayName}) async {
    if (_connecting) return false;
    
    _connecting = true;
    _connectedDeviceId = deviceId;
    _connectedDeviceName = displayName;
    
    final label = displayName ?? deviceId;
    onStatusChange('正在连接 $label...');
    onLog('connect start: $deviceId name=$label');

    await _adapter.stopScan();
    
    // Setup connection state listener
    await _connectionStateSub?.cancel();
    _connectionStateSub = _adapter.connectionStateStream(deviceId).listen((state) {
      onConnectionStateChange(state);
      
      if (state == AdapterConnectionState.connected) {
        _connectedAt = DateTime.now();
        onStatusChange('已连接', force: true);
      }
      
      if (state == AdapterConnectionState.disconnected) {
        _handleDisconnection();
      }
      
      onLog('connection state=$state');
    });

    try {
      await _adapter.connect(deviceId, timeout: const Duration(seconds: 10));
      
      _connectedAt = DateTime.now();
      onStatusChange('已连接，订阅心率中...', force: true);
      onLog('connected to $deviceId');
      
      // Subscribe to heart rate
      final subscribeSuccess = await _subscribeHeartRate(deviceId);
      _connecting = false;
      return subscribeSuccess;
    } catch (e) {
      onLog('connect failed', error: e);
      onStatusChange(_formatError(e, '连接失败'), force: true);
      _connectedAt = null;
      _connecting = false;
      return false;
    }
  }

  void _handleDisconnection() {
    _connectedAt = null;
    _heartRateSub?.cancel();
    _subscribed = false;
  }

  /// Disconnect from current device
  Future<void> disconnect() async {
    onLog('disconnect requested');
    onStatusChange('断开中...');
    
    _resubscribeTimer?.cancel();
    
    final deviceId = _connectedDeviceId;
    
    try {
      if (deviceId != null) {
        await _adapter.disconnect(deviceId);
      }
    } finally {
      await _connectionStateSub?.cancel();
      await _heartRateSub?.cancel();
      _subscribed = false;
      _connectedDeviceId = null;
      _connectedDeviceName = null;
      _connectedAt = null;
      _connecting = false;
      onStatusChange('已断开', force: true);
    }
  }

  /// Force reconnect due to stale connection
  Future<void> forceReconnect(String reason) async {
    onLog('force reconnect: $reason');
    if (_connectedDeviceId == null) return;
    
    onStatusChange('订阅心率失败，正在重连...', force: true);

    try {
      await _adapter.disconnect(_connectedDeviceId!);
    } catch (e) {
      onLog('disconnect during force reconnect failed', error: e);
    }

    _connectedAt = null;
    await _heartRateSub?.cancel();
    _subscribed = false;
  }

  Future<bool> _subscribeHeartRate(String deviceId, {int attempt = 0}) async {
    await _heartRateSub?.cancel();
    _resubscribeTimer?.cancel();
    _subscribed = false;
    _missingHrNotified = false;

    try {
      // Give device time to stabilize GATT
      final delay = Platform.isWindows ? _gattStableDelayWindows : _gattStableDelay;
      if (attempt == 0) {
        onStatusChange('订阅心率中...', force: true);
      }
      await Future.delayed(delay);

      onLog('subscribe hr attempt=$attempt');

      // Handle Xiaomi devices
      final deviceName = NearbyDevice.fixWindowsDeviceName(_connectedDeviceName ?? '');
      if (Platform.isWindows && BleScanner.isXiaomiDevice(deviceName)) {
        onLog('Xiaomi device detected, waiting for OS pairing');
        await Future.delayed(const Duration(milliseconds: 500));
      }

      // Discover services
      onLog('discovering services...');
      onStatusChange('发现服务中...', force: true);

      final services = await _discoverServicesWithRetry(deviceId);
      final serviceUuids = services.map((s) => s.uuid).join(', ');
      onLog('discovered ${services.length} services: [$serviceUuids]');

      // Find and subscribe to HR characteristic
      bool foundHr = false;
      for (final service in services) {
        if (service.uuid.toLowerCase() != _heartRateServiceUuid.toLowerCase()) continue;
        foundHr = true;

        for (final c in service.characteristics) {
          if (c.uuid.toLowerCase() == _heartRateMeasurementUuid.toLowerCase()) {
            final ok = await _enableHrNotifications(deviceId, c);
            if (ok) return true;
          }
        }
      }

      if (!foundHr) {
        onLog('HR service not found! Available: $serviceUuids');
      }

      if (!_missingHrNotified) {
        _missingHrNotified = true;
      }
      
      _scheduleResubscribe(deviceId, attempt: attempt + 1);
      return false;
    } catch (e, stackTrace) {
      onLog('subscribe hr failed: $e\nStack: $stackTrace');
      
      if (e is PlatformException && attempt < 1) {
        onStatusChange('订阅心率重试中...', force: true);
        await Future.delayed(const Duration(milliseconds: 800));
        return _subscribeHeartRate(deviceId, attempt: attempt + 1);
      }

      onStatusChange(_formatError(e, '订阅心率失败'), force: true);
      _scheduleResubscribe(deviceId, attempt: attempt + 1);
      return false;
    }
  }

  Future<List<BleServiceInfo>> _discoverServicesWithRetry(String deviceId) async {
    const maxRetries = 3;
    
    for (var retry = 0; retry < maxRetries; retry++) {
      try {
        if (retry > 0) {
          onLog('discoverServices retry $retry/$maxRetries');
          await Future.delayed(Duration(milliseconds: 1000 + retry * 500));
        }

        return await _adapter.discoverServices(deviceId).timeout(
          const Duration(seconds: 10),
          onTimeout: () => throw TimeoutException('discoverServices timed out'),
        );
      } catch (e) {
        final errorStr = e.toString().toLowerCase();
        final isDeviceNotFound = errorStr.contains('device not found') ||
            errorStr.contains('not found');

        if (isDeviceNotFound && retry < maxRetries - 1) {
          onLog('discoverServices "Device not found", retrying...');
          continue;
        }
        onLog('discoverServices failed: $e');
        rethrow;
      }
    }
    
    return [];
  }

  void _scheduleResubscribe(String deviceId, {required int attempt}) {
    if (attempt > 3) {
      forceReconnect('subscribe failed after $attempt attempts');
      return;
    }

    _resubscribeTimer?.cancel();
    _resubscribeTimer = Timer(const Duration(seconds: 2), () {
      if (_connectedDeviceId == deviceId) {
        _subscribeHeartRate(deviceId, attempt: attempt);
      }
    });
  }

  Future<bool> _enableHrNotifications(String deviceId, BleCharacteristicInfo c) async {
    onLog('enabling HR notifications for ${c.uuid}');
    const attempts = 2;
    
    for (var i = 0; i < attempts; i++) {
      try {
        onLog('setNotifyValue attempt ${i + 1}/$attempts');

        // Setup listener first
        _heartRateSub = _adapter.valueStream(deviceId, c.serviceUuid, c.uuid)
            .listen(onHeartRateData);

        // Enable notifications
        await _adapter.subscribeToCharacteristic(deviceId, c.serviceUuid, c.uuid);

        onLog('setNotifyValue succeeded');
        _resubscribeTimer?.cancel();
        _subscribed = true;
        _missingHrNotified = false;
        onStatusChange('已连接', force: true);
        return true;
      } catch (e) {
        onLog('setNotifyValue failed attempt ${i + 1}', error: e);
        if (i < attempts - 1) {
          await Future.delayed(const Duration(milliseconds: 400));
        }
      }
    }
    return false;
  }

  String _formatError(Object error, String fallback) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('timeout')) return '连接超时';
    if (msg.contains('cancelled') || msg.contains('canceled')) return '连接取消';
    if (msg.contains('disconnected')) return '设备断开';
    return fallback;
  }

  /// Dispose resources
  void dispose() {
    _resubscribeTimer?.cancel();
    _connectionStateSub?.cancel();
    _heartRateSub?.cancel();
  }
}
