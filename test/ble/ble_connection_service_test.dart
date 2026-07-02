import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/ble/ble_adapter.dart';
import 'package:hr_push/ble/ble_connection_service.dart';

void main() {
  test(
    'falls back to indication without leaving duplicate value listeners',
    () async {
      final adapter = _FakeBleAdapter(
        services: [
          BleServiceInfo(
            uuid: '0000180d-0000-1000-8000-00805f9b34fb',
            characteristics: [
              BleCharacteristicInfo(
                uuid: '00002a37-0000-1000-8000-00805f9b34fb',
                serviceUuid: '0000180d-0000-1000-8000-00805f9b34fb',
                canNotify: true,
                canIndicate: true,
              ),
            ],
          ),
        ],
      );
      addTearDown(adapter.dispose);

      final service = BleConnectionService(
        adapter: adapter,
        onLog: (_, {error}) {},
        onStatusChange: (_, {force = false}) {},
        onHeartRateData: (_) {},
        onConnectionStateChange: (_) {},
      );
      addTearDown(service.dispose);

      final success = await service.connect(
        'band-1',
        displayName: 'Mi Smart Band',
      );

      expect(success, isTrue);
      expect(adapter.subscriptionModes, [
        BleSubscriptionMode.notification,
        BleSubscriptionMode.indication,
      ]);
      expect(adapter.activeValueListeners, 1);
    },
  );
}

class _FakeBleAdapter implements BleAdapter {
  _FakeBleAdapter({required this.services});

  final List<BleServiceInfo> services;
  final subscriptionModes = <BleSubscriptionMode>[];
  final _scanController = StreamController<BleDeviceInfo>.broadcast();
  final _stateController = StreamController<BleAdapterState>.broadcast();
  final _connectionController =
      StreamController<AdapterConnectionState>.broadcast();
  final _valueController = StreamController<Uint8List>.broadcast();

  int activeValueListeners = 0;

  @override
  Stream<BleDeviceInfo> get scanStream => _scanController.stream;

  @override
  Stream<BleAdapterState> get adapterStateStream => _stateController.stream;

  @override
  Stream<AdapterConnectionState> connectionStateStream(String deviceId) {
    return _connectionController.stream;
  }

  @override
  Stream<Uint8List> valueStream(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) {
    return _valueController.stream;
  }

  @override
  Future<bool> isBluetoothAvailable() async => true;

  @override
  Future<BleAdapterState> getAdapterState() async => BleAdapterState.on;

  @override
  Future<void> startScan({List<String>? withServices}) async {}

  @override
  Future<void> stopScan() async {}

  @override
  Future<void> connect(String deviceId, {Duration? timeout}) async {
    _connectionController.add(AdapterConnectionState.connected);
  }

  @override
  Future<void> disconnect(String deviceId) async {
    _connectionController.add(AdapterConnectionState.disconnected);
  }

  @override
  Future<List<BleServiceInfo>> discoverServices(String deviceId) async =>
      services;

  @override
  Future<void> subscribeToCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid, {
    BleSubscriptionMode mode = BleSubscriptionMode.notification,
  }) async {
    subscriptionModes.add(mode);
    activeValueListeners++;
    if (mode == BleSubscriptionMode.notification) {
      activeValueListeners--;
      throw StateError('notification rejected');
    }
  }

  @override
  Future<void> unsubscribeFromCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) async {}

  @override
  Future<Uint8List> readCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
  ) async {
    return Uint8List(0);
  }

  @override
  Future<void> writeCharacteristic(
    String deviceId,
    String serviceUuid,
    String characteristicUuid,
    Uint8List data, {
    bool withResponse = true,
  }) async {}

  @override
  void dispose() {
    _scanController.close();
    _stateController.close();
    _connectionController.close();
    _valueController.close();
  }
}
