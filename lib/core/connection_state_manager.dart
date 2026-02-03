import '../ble/ble_adapter.dart';

/// Connection state change event
class ConnectionStateEvent {
  const ConnectionStateEvent({
    required this.connected,
    required this.deviceId,
    required this.deviceName,
    required this.timestamp,
  });

  final bool connected;
  final String? deviceId;
  final String? deviceName;
  final DateTime timestamp;

  Map<String, dynamic> toPayload() => {
    'event': 'connection',
    'connected': connected,
    'device': deviceName,
    'timestamp': timestamp.toIso8601String(),
  };
}

/// Manages BLE connection state and stale connection detection
class ConnectionStateManager {
  ConnectionStateManager({
    required this.onLog,
    required this.onStateChange,
    required this.onStaleConnectionDetected,
    this.staleThreshold = const Duration(seconds: 12),
  });

  final void Function(String message) onLog;
  final void Function(ConnectionStateEvent event) onStateChange;
  final void Function() onStaleConnectionDetected;
  final Duration staleThreshold;

  AdapterConnectionState _connectionState = AdapterConnectionState.disconnected;
  BleAdapterState _adapterState = BleAdapterState.unknown;
  DateTime? _connectedAt;
  String? _connectedDeviceId;
  String? _connectedDeviceName;
  bool _connecting = false;
  bool _userInitiatedDisconnect = false;
  bool _autoReconnect = true;

  // Getters
  AdapterConnectionState get connectionState => _connectionState;
  BleAdapterState get adapterState => _adapterState;
  DateTime? get connectedAt => _connectedAt;
  String? get connectedDeviceId => _connectedDeviceId;
  String? get connectedDeviceName => _connectedDeviceName;
  bool get isConnecting => _connecting;
  bool get isConnected => _connectionState == AdapterConnectionState.connected;
  bool get isBluetoothOn => _adapterState == BleAdapterState.on;
  bool get userInitiatedDisconnect => _userInitiatedDisconnect;
  bool get autoReconnect => _autoReconnect;

  /// Update adapter state
  void updateAdapterState(BleAdapterState state) {
    _adapterState = state;
  }

  /// Start connecting to a device
  void startConnecting(String deviceId, String? deviceName) {
    _connecting = true;
    _connectedDeviceId = deviceId;
    _connectedDeviceName = deviceName;
    _userInitiatedDisconnect = false;
    _connectionState = AdapterConnectionState.disconnected;
  }

  /// Mark connection as established
  void markConnected() {
    _connectionState = AdapterConnectionState.connected;
    _connectedAt = DateTime.now();
    _connecting = false;
    _notifyStateChange();
  }

  /// Mark connection as disconnected
  void markDisconnected({bool userInitiated = false}) {
    _connectionState = AdapterConnectionState.disconnected;
    _connectedAt = null;
    _connecting = false;
    
    if (userInitiated) {
      _userInitiatedDisconnect = true;
      _autoReconnect = false;
      _connectedDeviceId = null;
      _connectedDeviceName = null;
    }
    
    _notifyStateChange();
  }

  /// Finish connecting attempt (success or failure)
  void finishConnecting() {
    _connecting = false;
  }

  /// Set auto reconnect flag
  void setAutoReconnect(bool value) {
    _autoReconnect = value;
  }

  /// Set user initiated disconnect flag
  void setUserInitiatedDisconnect(bool value) {
    _userInitiatedDisconnect = value;
  }

  /// Clear device info (on full disconnect)
  void clearDevice() {
    _connectedDeviceId = null;
    _connectedDeviceName = null;
    _connectedAt = null;
  }

  /// Check for stale connection (no HR data for too long)
  void checkStaleConnection({
    required DateTime now,
    required DateTime? lastHeartRateAt,
  }) {
    if (_connecting) return;
    if (_connectionState != AdapterConnectionState.connected) return;
    if (lastHeartRateAt == null) return;

    if (now.difference(lastHeartRateAt) > staleThreshold) {
      onLog('stale connection detected, forcing reconnect');
      _connectionState = AdapterConnectionState.disconnected;
      _connectedAt = null;
      onStaleConnectionDetected();
    }
  }

  void _notifyStateChange() {
    onStateChange(ConnectionStateEvent(
      connected: isConnected,
      deviceId: _connectedDeviceId,
      deviceName: _connectedDeviceName,
      timestamp: DateTime.now(),
    ));
  }
}
