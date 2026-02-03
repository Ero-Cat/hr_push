import 'dart:async';
import 'dart:typed_data';

import '../ble/ble_adapter.dart';
import '../ble/ble_scanner.dart';
import '../models/heart_rate_settings.dart';
import '../services/push_coordinator.dart';

/// Heart rate update event
class HeartRateEvent {
  const HeartRateEvent({
    required this.bpm,
    this.percent,
    this.rssi,
    required this.timestamp,
    required this.connected,
    this.deviceName,
  });

  final int bpm;
  final double? percent;
  final int? rssi;
  final DateTime timestamp;
  final bool connected;
  final String? deviceName;

  Map<String, dynamic> toPayload() => {
    'event': 'heartRate',
    'heartRate': bpm,
    'percent': percent,
    'connected': connected,
    'device': deviceName,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Processes heart rate data and manages publishing
class HeartRateProcessor {
  HeartRateProcessor({
    required PushCoordinator pushCoordinator,
    required this.onLog,
    required this.onHeartRateUpdate,
    required this.onHrOnlineChange,
  }) : _pushCoordinator = pushCoordinator;

  final PushCoordinator _pushCoordinator;
  final void Function(String message) onLog;
  final void Function(HeartRateEvent event) onHeartRateUpdate;
  final void Function(bool online) onHrOnlineChange;

  HeartRateSettings _settings = HeartRateSettings.defaults();

  int? _heartRate;
  int? _rssi;
  DateTime? _lastUpdated;
  DateTime? _lastHrSeenAt;
  DateTime? _prevHeartRateAt;
  DateTime? _lastPublished;
  bool _hrOnline = false;

  static const Duration _hrStaleThreshold = Duration(seconds: 6);

  // Getters
  int? get heartRate => isHeartRateFresh ? _heartRate : null;
  int? get rawHeartRate => _heartRate;
  int? get rssi => _rssi;
  DateTime? get lastUpdated => _lastUpdated;
  DateTime? get lastHrSeenAt => _lastHrSeenAt;
  bool get hrOnline => _hrOnline;

  bool get isHeartRateFresh =>
      _lastUpdated != null &&
      DateTime.now().difference(_lastUpdated!) <= _hrStaleThreshold;

  double? get heartRatePercent {
    if (_heartRate == null || _settings.maxHeartRate <= 0) return null;
    final percent = _heartRate! / _settings.maxHeartRate;
    return percent.clamp(0, 1).toDouble();
  }

  int? get lastIntervalMs => _lastUpdated != null && _prevHeartRateAt != null
      ? _lastUpdated!.difference(_prevHeartRateAt!).inMilliseconds
      : null;

  /// Update settings
  void updateSettings(HeartRateSettings value) {
    _settings = value;
    _pushCoordinator.updateSettings(value);
  }

  /// Process heart rate data from BLE notification
  void handleHeartRateData(Uint8List data, {bool connected = true, String? deviceName}) {
    if (data.isEmpty) return;
    final bpm = BleScanner.parseHeartRateValue(data);
    if (bpm == null) return;
    
    _processHeartRate(
      bpm: bpm, 
      rssi: null,
      connected: connected,
      deviceName: deviceName,
    );
  }

  /// Process broadcast heart rate from advertisement
  void handleBroadcastHeartRate(BleDeviceInfo device) {
    final bpm = BleScanner.extractBroadcastHeartRate(device);
    if (bpm == null) return;
    
    _processHeartRate(
      bpm: bpm, 
      rssi: device.rssi,
      connected: false,
      deviceName: device.name,
    );
  }

  void _processHeartRate({
    required int bpm,
    int? rssi,
    required bool connected,
    String? deviceName,
  }) {
    final now = DateTime.now();
    onLog('hr rx: bpm=$bpm rssi=$rssi');
    
    _prevHeartRateAt = _lastUpdated;
    _heartRate = bpm;
    _rssi = rssi ?? _rssi;
    _lastUpdated = now;
    _lastHrSeenAt = now;

    syncHrOnline(now: now, connected: connected);
    
    if (!_shouldPublishNow(now)) return;
    _lastPublished = now;
    _publishHeartRate(connected: connected, deviceName: deviceName);
  }

  bool _shouldPublishNow(DateTime now) {
    if (_lastPublished == null) return true;
    return now.difference(_lastPublished!) >=
        Duration(milliseconds: _settings.updateIntervalMs);
  }

  void _publishHeartRate({required bool connected, String? deviceName}) {
    final bpm = _heartRate;
    if (bpm == null) return;

    final event = HeartRateEvent(
      bpm: bpm,
      percent: heartRatePercent,
      rssi: _rssi,
      timestamp: DateTime.now(),
      connected: connected,
      deviceName: deviceName,
    );

    onLog('publish hr: bpm=$bpm percent=${heartRatePercent != null ? (heartRatePercent! * 100).round() : '-'}%');
    
    // Send to push services
    unawaited(_pushCoordinator.sendHeartRate(
      bpm: bpm,
      percent: heartRatePercent,
      timestamp: event.timestamp,
    ));
    unawaited(_pushCoordinator.sendConnectionStatus(_hrOnline, force: true));
    unawaited(_pushCoordinator.sendChatbox(bpm, heartRatePercent));

    onHeartRateUpdate(event);
  }

  /// Sync heart rate online status
  void syncHrOnline({DateTime? now, bool forceOsc = false, bool connected = true}) {
    now ??= DateTime.now();
    final wasOnline = _hrOnline;

    _hrOnline = computeHrOnline(
      connected: connected,
      now: now,
      lastHeartRateAt: _lastHrSeenAt,
      hrFreshFor: _hrStaleThreshold,
    );

    if (_hrOnline != wasOnline || forceOsc) {
      onHrOnlineChange(_hrOnline);
      unawaited(_pushCoordinator.sendConnectionStatus(_hrOnline, force: forceOsc));
    }
  }

  /// Compute if heart rate should be considered online
  static bool computeHrOnline({
    required bool connected,
    required DateTime now,
    required DateTime? lastHeartRateAt,
    Duration hrFreshFor = const Duration(seconds: 6),
  }) {
    if (!connected) return false;

    // Check if HR data is fresh
    if (lastHeartRateAt != null &&
        now.difference(lastHeartRateAt) <= hrFreshFor) {
      return true;
    }

    return false;
  }

  /// Reset all heart rate state
  void reset() {
    _heartRate = null;
    _rssi = null;
    _lastUpdated = null;
    _lastHrSeenAt = null;
    _prevHeartRateAt = null;
    _hrOnline = false;
  }
}
