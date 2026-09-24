import 'dart:async';
import 'dart:typed_data';

import 'package:universal_ble/universal_ble.dart';

import 'ble_adapter.dart';

/// Implementation of BleAdapter using the universal_ble package
/// This provides cross-platform BLE support including Windows via WinRT
class UniversalBleAdapter implements BleAdapter {
  final _scanController = StreamController<BleDeviceInfo>.broadcast();
  final _connectionControllers =
      <String, StreamController<AdapterConnectionState>>{};
  final _valueControllers = <String, StreamController<Uint8List>>{};
  final _adapterStateController = StreamController<BleAdapterState>.broadcast();

  bool _isInitialized = false;
  bool _isScanning = false;

  UniversalBleAdapter() {
    _initialize();
  }

  void _initialize() {
    if (_isInitialized) return;
    _isInitialized = true;

    // Set up adapter availability handler
    UniversalBle.onAvailabilityChange = (state) {
      _adapterStateController.add(_mapAvailabilityState(state));
    };

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
    UniversalBle.onValueChange =
        (deviceId, characteristicId, value, timestamp) {
          final key = '$deviceId:$characteristicId';
          if (_valueControllers.containsKey(key)) {
            _valueControllers[key]!.add(Uint8List.fromList(value));
          }
        };
  }

  BleAdapterState _mapAvailabilityState(AvailabilityState state) {
    switch (state) {
      case AvailabilityState.poweredOn:
        return BleAdapterState.on;
      case AvailabilityState.poweredOff:
        return BleAdapterState.off;
      case AvailabilityState.unsupported:
        return BleAdapterState.unavailable;
      case AvailabilityState.unauthorized:
        return BleAdapterState.unauthorized;
      case AvailabilityState.unknown:
      default:
        return BleAdapterState.unknown;
    }
  }

  StreamController<AdapterConnectionState> _getConnectionController(
    String deviceId,
  ) {
    _connectionControllers[deviceId] ??=
        StreamController<AdapterConnectionState>.broadcast();
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
  Stream<Uint8List> valueStream(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) {
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
  Stream<BleAdapterState> get adapterStateStream =>
      _adapterStateController.stream;

  @override
  Future<BleAdapterState> getAdapterState() async {
    final state = await UniversalBle.getBluetoothAvailabilityState();
    return _mapAvailabilityState(state);
  }

  @override
  Future<void> startScan({List<String>? withServices}) async {
    if (_isScanning) return;
    _isScanning = true;

    try {
      await UniversalBle.startScan(
        scanFilter: withServices != null
            ? ScanFilter(withServices: withServices)
            : null,
      );
    } catch (_) {
      // Android throttles frequent scan restarts ("scanning too frequently").
      // Without resetting the flag here every later startScan call would
      // silently no-op until an explicit stopScan.
      _isScanning = false;
      rethrow;
    }
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
      // universal_ble defaults to a 60s timeout when none is passed, which
      // hangs the whole connect path on uncooperative devices; honor the
      // caller's timeout instead.
      await UniversalBle.connect(deviceId, timeout: timeout);
    } catch (e) {
      _getConnectionController(
        deviceId,
      ).add(AdapterConnectionState.disconnected);
      rethrow;
    }
  }

  @override
  Future<void> disconnect(String deviceId) async {
    _getConnectionController(
      deviceId,
    ).add(AdapterConnectionState.disconnecting);
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
            canWrite:
                char.properties.contains(CharacteristicProperty.write) ||
                char.properties.contains(
                  CharacteristicProperty.writeWithoutResponse,
                ),
            canNotify: char.properties.contains(CharacteristicProperty.notify),
            canIndicate: char.properties.contains(
              CharacteristicProperty.indicate,
            ),
          );
        }).toList(),
      );
    }).toList();
  }

  @override
  Future<void> subscribeToCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid, {
    BleSubscriptionMode mode = BleSubscriptionMode.notification,
  }) async {
    // Ensure we have a controller for this characteristic
    final key = _valueKey(deviceId, serviceUuid, characteristicUuid);
    _valueControllers[key] ??= StreamController<Uint8List>.broadcast();

    // Subscribe to notifications
    // ignore: deprecated_member_use
    await UniversalBle.setNotifiable(
      deviceId,
      serviceUuid,
      characteristicUuid,
      mode == BleSubscriptionMode.indication
          ? BleInputProperty.indication
          : BleInputProperty.notification,
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
      withResponse
          ? BleOutputProperty.withResponse
          : BleOutputProperty.withoutResponse,
    );
  }

  /// Release per-device resources. Call after a device disconnects so the
  /// controller maps do not grow unboundedly (Xiaomi devices rotate MACs, so
  /// long sessions would otherwise accumulate one entry per address).
  @override
  void cleanupDevice(String deviceId) {
    _connectionControllers.remove(deviceId)?.close();
    _valueControllers.removeWhere((key, _) => key.startsWith('$deviceId:'));
  }

  @override
  void dispose() {
    UniversalBle.onAvailabilityChange = null;
    UniversalBle.onScanResult = null;
    UniversalBle.onConnectionChange = null;
    UniversalBle.onValueChange = null;

    _scanController.close();
    _adapterStateController.close();
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
