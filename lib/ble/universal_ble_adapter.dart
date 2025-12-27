import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'ble_adapter.dart';

/// Implementation of BleAdapter using the universal_ble package
/// This provides cross-platform BLE support including Windows via WinRT
class UniversalBleAdapter implements BleAdapter {
  final _scanController = StreamController<BleDeviceInfo>.broadcast();
  final _connectionControllers = <String, StreamController<AdapterConnectionState>>{};
  final _valueControllers = <String, StreamController<Uint8List>>{};
  
  bool _isInitialized = false;
  bool _isScanning = false;

  UniversalBleAdapter() {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Set up scan result handler
    UniversalBle.onScanResult = (device) {
      final mfgData = <int, Uint8List>{};
      for (final entry in device.manufacturerDataList) {
        mfgData[entry.companyId] = entry.payload;
      }
      
      final deviceInfo = BleDeviceInfo(
        id: device.deviceId,
        name: device.name ?? '',
        rssi: device.rssi ?? -100,
        connectable: true,
        serviceUuids: device.services.map((s) => s.toString()).toList(),
        manufacturerData: mfgData,
      );
      _scanController.add(deviceInfo);
    };

    // Set up connection state handler
    UniversalBle.onConnectionChange = (deviceId, isConnected, error) {
      final state = isConnected 
          ? AdapterConnectionState.connected 
          : AdapterConnectionState.disconnected;
      _getConnectionController(deviceId).add(state);
    };

    // Set up value change handler
    UniversalBle.onValueChange = (deviceId, characteristicId, value, timestamp) {
      final key = '$deviceId:$characteristicId';
      if (_valueControllers.containsKey(key)) {
        _valueControllers[key]!.add(Uint8List.fromList(value));
      }
    };
  }

  StreamController<AdapterConnectionState> _getConnectionController(String deviceId) {
    _connectionControllers[deviceId] ??= StreamController<AdapterConnectionState>.broadcast();
    return _connectionControllers[deviceId]!;
  }

  String _valueKey(String deviceId, String serviceUuid, String charUuid) {
    return '$deviceId:$charUuid';
  }

  @override
  Stream<BleDeviceInfo> get scanStream => _scanController.stream;

  @override
  Stream<AdapterConnectionState> connectionStateStream(String deviceId) {
    return _getConnectionController(deviceId).stream;
  }

  @override
  Stream<Uint8List> valueStream(String deviceId, String serviceUuid, String characteristicUuid) {
    final key = _valueKey(deviceId, serviceUuid, characteristicUuid);
    _valueControllers[key] ??= StreamController<Uint8List>.broadcast();
    return _valueControllers[key]!.stream;
  }

  @override
  Future<bool> isBluetoothAvailable() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return state == AvailabilityState.poweredOn;
  }

  @override
  Future<void> startScan({List<String>? withServices}) async {
    if (_isScanning) return;
    _isScanning = true;
    
    await UniversalBle.startScan(
      scanFilter: withServices != null
          ? ScanFilter(withServices: withServices)
          : null,
    );
  }

  @override
  Future<void> stopScan() async {
    if (!_isScanning) return;
    _isScanning = false;
    await UniversalBle.stopScan();
  }

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    _getConnectionController(deviceId).add(AdapterConnectionState.connecting);
    
    try {
      await UniversalBle.connect(deviceId);
    } catch (e) {
      _getConnectionController(deviceId).add(AdapterConnectionState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    _getConnectionController(deviceId).add(AdapterConnectionState.disconnecting);
    await UniversalBle.disconnect(deviceId);
  }

  @override
  Future<List<BleServiceInfo>> discoverServices(String deviceId) async {
    final services = await UniversalBle.discoverServices(deviceId);
    
    return services.map((service) {
      return BleServiceInfo(
        uuid: service.uuid,
        characteristics: service.characteristics.map((char) {
          return BleCharacteristicInfo(
            uuid: char.uuid,
            serviceUuid: service.uuid,
            canRead: char.properties.contains(CharacteristicProperty.read),
            canWrite: char.properties.contains(CharacteristicProperty.write) ||
                char.properties.contains(CharacteristicProperty.writeWithoutResponse),
            canNotify: char.properties.contains(CharacteristicProperty.notify) ||
                char.properties.contains(CharacteristicProperty.indicate),
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  Future<void> subscribeToCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    // Ensure we have a controller for this characteristic
    final key = _valueKey(deviceId, serviceUuid, characteristicUuid);
    _valueControllers[key] ??= StreamController<Uint8List>.broadcast();
    
    // Subscribe to notifications
    // ignore: deprecated_member_use
    await UniversalBle.setNotifiable(
      deviceId,
      serviceUuid,
      characteristicUuid,
      BleInputProperty.notification,
    );
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    // ignore: deprecated_member_use
    await UniversalBle.setNotifiable(
      deviceId,
      serviceUuid,
      characteristicUuid,
      BleInputProperty.disabled,
    );
  }

  @override
  Future<Uint8List> readCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    // ignore: deprecated_member_use
    final value = await UniversalBle.readValue(
      deviceId,
      serviceUuid,
      characteristicUuid,
    );
    return Uint8List.fromList(value);
  }

  @override
  Future<void> writeCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data, {
    bool withResponse = true,
  }) async {
    // ignore: deprecated_member_use
    await UniversalBle.writeValue(
      deviceId,
      serviceUuid,
      characteristicUuid,
      data,
      withResponse ? BleOutputProperty.withResponse : BleOutputProperty.withoutResponse,
    );
  }

  @override
  void dispose() {
    _scanController.close();
    for (final controller in _connectionControllers.values) {
      controller.close();
    }
    for (final controller in _valueControllers.values) {
      controller.close();
    }
    _connectionControllers.clear();
    _valueControllers.clear();
  }
}
