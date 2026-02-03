import 'dart:async';

import '../models/heart_rate_settings.dart';
import '../services/push_coordinator.dart';

/// Handles heart rate data processing and publishing
class HeartRateHandler {
  HeartRateHandler({
    required PushCoordinator pushCoordinator,
    required this.onLog,
    required this.onStatusChange,
    required this.onHrOnlineChange,
  }) : _pushCoordinator = pushCoordinator;

  final PushCoordinator _pushCoordinator;
  final void Function(String message, {Object? error}) onLog;
  final void Function(String status) onStatusChange;
  final void Function(bool online) onHrOnlineChange;

  HeartRateSettings _settings = HeartRateSettings.defaults();

  int? _heartRate;
  int? _rssi;
  DateTime? _lastUpdated;
  DateTime? _lastHrSeenAt;
  DateTime? _prevHeartRateAt;
  DateTime? _lastPublished;
  DateTime? _connectedAt;
  bool _hrOnline = false;
  bool _userInitiatedDisconnect = false;
  bool _connected = false;

  static const Duration _hrStaleThreshold = Duration(seconds: 6);

  // Getters
  int? get heartRate => isHeartRateFresh ? _heartRate : null;
  int? get rssi => _connected ? _rssi : null;
  DateTime? get lastUpdated => _lastUpdated;
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

  /// Update connection state
  void setConnectionState({
    required bool connected,
    required bool userInitiatedDisconnect,
    DateTime? connectedAt,
  }) {
    _connected = connected;
    _userInitiatedDisconnect = userInitiatedDisconnect;
    _connectedAt = connectedAt;

    if (!connected) {
      _heartRate = null;
      _rssi = null;
      _lastUpdated = null;
      _prevHeartRateAt = null;
    }
  }

  /// Process heart rate data
  void handleHeartRateData({
    required int bpm,
    required int? rssi,
    required DateTime timestamp,
  }) {
    _prevHeartRateAt = _lastUpdated;
    _heartRate = bpm;
    _rssi = rssi;
    _lastUpdated = timestamp;
    _lastHrSeenAt = timestamp;

    syncHrOnline(now: timestamp);
  }

  /// Check if we should publish now based on interval
  bool shouldPublishNow(DateTime now) {
    if (_lastPublished == null) return true;
    return now.difference(_lastPublished!) >=
        Duration(milliseconds: _settings.updateIntervalMs);
  }

  /// Publish heart rate update
  Future<void> publishHeartRateUpdate({DateTime? now}) async {
    now ??= DateTime.now();
    if (!shouldPublishNow(now)) return;
    _lastPublished = now;
    await _sendHeartRateUpdate();
  }

  Future<void> _sendHeartRateUpdate() async {
    final bpm = _heartRate;
    if (bpm == null) return;

    final now = DateTime.now();
    await _pushCoordinator.sendHeartRate(
      bpm: bpm,
      percent: heartRatePercent,
      timestamp: now,
    );
    await _pushCoordinator.sendChatbox(bpm, heartRatePercent);
  }

  /// Sync heart rate online status
  void syncHrOnline({DateTime? now, bool forceOsc = false}) {
    now ??= DateTime.now();
    final wasOnline = _hrOnline;

    _hrOnline = computeHrOnline(
      userInitiatedDisconnect: _userInitiatedDisconnect,
      connected: _connected,
      now: now,
      lastHeartRateAt: _lastHrSeenAt,
      connectedAt: _connectedAt,
    );

    if (_hrOnline != wasOnline || forceOsc) {
      onHrOnlineChange(_hrOnline);
      unawaited(_pushCoordinator.sendConnectionStatus(_hrOnline, force: forceOsc));
    }
  }

  /// Compute if heart rate should be considered online
  static bool computeHrOnline({
    required bool userInitiatedDisconnect,
    required bool connected,
    required DateTime now,
    required DateTime? lastHeartRateAt,
    required DateTime? connectedAt,
    Duration hrFreshFor = const Duration(seconds: 6),
    Duration initialGrace = const Duration(seconds: 3),
  }) {
    if (userInitiatedDisconnect) return false;
    if (!connected) return false;

    // Just connected, give grace period
    if (connectedAt != null &&
        now.difference(connectedAt) < initialGrace &&
        lastHeartRateAt == null) {
      return true;
    }

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
