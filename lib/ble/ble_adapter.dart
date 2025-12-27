import 'dart:async';
import 'dart:typed_data';

/// Represents a discovered BLE device
class BleDeviceInfo {
  final String id;
  final String name;
  final int rssi;
  final bool connectable;
  final List<String> serviceUuids;
  final Map<String, Uint8List> serviceData;
  final Map<int, Uint8List> manufacturerData;

  BleDeviceInfo({
    required this.id,
    required this.name,
    required this.rssi,
    this.connectable = true,
    this.serviceUuids = const [],
    this.serviceData = const {},
    this.manufacturerData = const {},
  });
}

/// Represents a BLE service
class BleServiceInfo {
  final String uuid;
  final List<BleCharacteristicInfo> characteristics;

  BleServiceInfo({
    required this.uuid,
    this.characteristics = const [],
  });
}

/// Represents a BLE characteristic
class BleCharacteristicInfo {
  final String uuid;
  final String serviceUuid;
  final bool canRead;
  final bool canWrite;
  final bool canNotify;

  BleCharacteristicInfo({
    required this.uuid,
    required this.serviceUuid,
    this.canRead = false,
    this.canWrite = false,
    this.canNotify = false,
  });
}

/// Connection state enum (renamed to avoid conflict with universal_ble)
enum AdapterConnectionState {
  disconnected,
  connecting,
  connected,
  disconnecting,
}

/// Abstract BLE adapter interface
/// This allows swapping between different BLE implementations
abstract class BleAdapter {
  /// Stream of discovered devices during scanning
  Stream<BleDeviceInfo> get scanStream;

  /// Stream of connection state changes for a device
  Stream<AdapterConnectionState> connectionStateStream(String deviceId);

  /// Stream of values received from subscribed characteristics
  Stream<Uint8List> valueStream(String deviceId, String serviceUuid, String characteristicUuid);

  /// Check if Bluetooth is available and enabled
  Future<bool> isBluetoothAvailable();

  /// Start scanning for BLE devices
  /// [withServices] - Optional list of service UUIDs to filter by
  Future<void> startScan({List<String>? withServices});

  /// Stop scanning
  Future<void> stopScan();

  /// Connect to a device
  Future<void> connect(String deviceId, {Duration? timeout});

  /// Disconnect from a device
  Future<void> disconnect(String deviceId);

  /// Discover services on a connected device
  Future<List<BleServiceInfo>> discoverServices(String deviceId);

  /// Subscribe to characteristic notifications
  Future<void> subscribeToCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  );

  /// Unsubscribe from characteristic notifications
  Future<void> unsubscribeFromCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  );

  /// Read characteristic value
  Future<Uint8List> readCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  );

  /// Write characteristic value
  Future<void> writeCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data, {
    bool withResponse = true,
  });

  /// Dispose resources
  void dispose();
}
