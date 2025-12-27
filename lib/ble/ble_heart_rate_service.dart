import 'dart:async';
import 'dart:typed_data';

import 'ble_adapter.dart';
import 'universal_ble_adapter.dart';

/// Standard BLE Heart Rate Service UUID
const String heartRateServiceUuid = '180d';
const String heartRateServiceUuidFull = '0000180d-0000-1000-8000-00805f9b34fb';

/// Standard BLE Heart Rate Measurement Characteristic UUID
const String heartRateMeasurementUuid = '2a37';
const String heartRateMeasurementUuidFull = '00002a37-0000-1000-8000-00805f9b34fb';

/// Heart rate data received from BLE device
class HeartRateData {
  final int bpm;
  final bool sensorContact;
  final DateTime timestamp;
  
  HeartRateData({
    required this.bpm,
    this.sensorContact = true,
    DateTime? timestamp,
  }) : timestamp = timestamp ?? DateTime.now();
}

/// Encapsulates BLE heart rate functionality using the BleAdapter
class BleHeartRateService {
  final BleAdapter _adapter;
  
  String? _connectedDeviceId;
  StreamSubscription? _valueSubscription;
  StreamSubscription? _connectionSubscription;
  
  final _heartRateController = StreamController<HeartRateData>.broadcast();
  final _connectionStateController = StreamController<AdapterConnectionState>.broadcast();
  final _scanResultController = StreamController<BleDeviceInfo>.broadcast();
  
  StreamSubscription? _scanSubscription;
  
  /// Stream of heart rate data
  Stream<HeartRateData> get heartRateStream => _heartRateController.stream;
  
  /// Stream of connection state changes
  Stream<AdapterConnectionState> get connectionStateStream => _connectionStateController.stream;
  
  /// Stream of discovered heart rate devices
  Stream<BleDeviceInfo> get scanStream => _scanResultController.stream;
  
  /// Currently connected device ID
  String? get connectedDeviceId => _connectedDeviceId;
  
  /// Whether currently connected to a device
  bool get isConnected => _connectedDeviceId != null;
  
  /// Create with default UniversalBleAdapter
  factory BleHeartRateService.create() {
    return BleHeartRateService(UniversalBleAdapter());
  }
  
  BleHeartRateService(this._adapter);
  
  /// Check if Bluetooth is available
  Future<bool> isBluetoothAvailable() => _adapter.isBluetoothAvailable();
  
  /// Start scanning for heart rate devices
  Future<void> startScan() async {
    await _adapter.startScan(withServices: [heartRateServiceUuid]);
    
    _scanSubscription?.cancel();
    _scanSubscription = _adapter.scanStream.listen((device) {
      // Filter to only heart rate devices
      final hasHrService = device.serviceUuids.any((uuid) =>
          uuid.toLowerCase().contains(heartRateServiceUuid) ||
          uuid.toLowerCase().contains(heartRateServiceUuidFull));
      
      if (hasHrService || device.name.toLowerCase().contains('heart') ||
          device.name.toLowerCase().contains('polar') ||
          device.name.toLowerCase().contains('wahoo') ||
          device.name.toLowerCase().contains('garmin') ||
          device.name.toLowerCase().contains('xiaomi') ||
          device.name.toLowerCase().contains('coospo')) {
        _scanResultController.add(device);
      }
    });
  }
  
  /// Stop scanning
  Future<void> stopScan() async {
    await _adapter.stopScan();
    _scanSubscription?.cancel();
    _scanSubscription = null;
  }
  
  /// Connect to a heart rate device and subscribe to heart rate data
  Future<void> connect(String deviceId) async {
    if (_connectedDeviceId != null) {
      await disconnect();
    }
    
    _connectionStateController.add(AdapterConnectionState.connecting);
    
    // Listen to connection state changes
    _connectionSubscription?.cancel();
    _connectionSubscription = _adapter.connectionStateStream(deviceId).listen((state) {
      _connectionStateController.add(state);
      
      if (state == AdapterConnectionState.disconnected) {
        _connectedDeviceId = null;
        _valueSubscription?.cancel();
        _valueSubscription = null;
      }
    });
    
    try {
      // Connect to device
      await _adapter.connect(deviceId, timeout: const Duration(seconds: 15));
      _connectedDeviceId = deviceId;
      
      // Discover services
      final services = await _adapter.discoverServices(deviceId);
      
      // Find heart rate service
      final hrService = services.firstWhere(
        (s) => s.uuid.toLowerCase().contains(heartRateServiceUuid),
        orElse: () => throw Exception('Heart Rate Service not found'),
      );
      
      // Find heart rate measurement characteristic
      final hrChar = hrService.characteristics.firstWhere(
        (c) => c.uuid.toLowerCase().contains(heartRateMeasurementUuid),
        orElse: () => throw Exception('Heart Rate Measurement Characteristic not found'),
      );
      
      // Subscribe to notifications
      await _adapter.subscribeToCharacteristic(
        deviceId,
        hrService.uuid,
        hrChar.uuid,
      );
      
      // Listen to heart rate values
      _valueSubscription = _adapter.valueStream(deviceId, hrService.uuid, hrChar.uuid)
          .listen((data) {
        final hrData = _parseHeartRateData(data);
        if (hrData != null) {
          _heartRateController.add(hrData);
        }
      });
      
      _connectionStateController.add(AdapterConnectionState.connected);
      
    } catch (e) {
      _connectedDeviceId = null;
      _connectionStateController.add(AdapterConnectionState.disconnected);
      rethrow;
    }
  }
  
  /// Disconnect from current device
  Future<void> disconnect() async {
    if (_connectedDeviceId == null) return;
    
    final deviceId = _connectedDeviceId!;
    _connectionStateController.add(AdapterConnectionState.disconnecting);
    
    _valueSubscription?.cancel();
    _valueSubscription = null;
    
    _connectionSubscription?.cancel();
    _connectionSubscription = null;
    
    try {
      await _adapter.disconnect(deviceId);
    } finally {
      _connectedDeviceId = null;
      _connectionStateController.add(AdapterConnectionState.disconnected);
    }
  }
  
  /// Parse heart rate data according to BLE Heart Rate Profile specification
  HeartRateData? _parseHeartRateData(Uint8List data) {
    if (data.isEmpty) return null;
    
    final flags = data[0];
    
    // Bit 0: Heart Rate Value Format
    // 0 = UINT8, 1 = UINT16
    final isUint16 = (flags & 0x01) != 0;
    
    int bpm;
    if (isUint16) {
      if (data.length < 3) return null;
      bpm = data[1] | (data[2] << 8);
    } else {
      if (data.length < 2) return null;
      bpm = data[1];
    }
    
    // Bit 1-2: Sensor Contact Status
    // Bit 1: Sensor Contact Supported
    // Bit 2: Sensor Contact Detected
    final sensorContactSupported = (flags & 0x04) != 0;
    final sensorContactDetected = sensorContactSupported ? (flags & 0x02) != 0 : true;
    
    // Validate BPM range
    if (bpm < 30 || bpm > 250) return null;
    
    return HeartRateData(
      bpm: bpm,
      sensorContact: sensorContactDetected,
    );
  }
  
  /// Dispose resources
  void dispose() {
    _scanSubscription?.cancel();
    _valueSubscription?.cancel();
    _connectionSubscription?.cancel();
    _heartRateController.close();
    _connectionStateController.close();
    _scanResultController.close();
    _adapter.dispose();
  }
}
