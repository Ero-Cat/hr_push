import 'dart:typed_data';

import '../models/nearby_device.dart';
import 'ble_adapter.dart';

/// BLE device scanning and identification service
class BleScanner {
  BleScanner({
    required this.onLog,
    required this.onDeviceFound,
    required this.onBroadcastHeartRate,
  });

  final void Function(String message, {Object? error}) onLog;
  final void Function(NearbyDevice device, bool isNew) onDeviceFound;
  final void Function(int bpm, int rssi, String deviceName) onBroadcastHeartRate;

  final List<NearbyDevice> _nearby = [];
  
  static const Duration nearbyTtl = Duration(seconds: 8);
  static const String _heartRateServiceUuid = '0000180d-0000-1000-8000-00805f9b34fb';

  List<NearbyDevice> get nearbyDevices => List.unmodifiable(_nearby);

  /// Handle a scan result from BLE adapter
  void handleScanResult(BleDeviceInfo r) {
    if (isLikelyPhoneOrPc(r)) return;
    if (!isWearableHeartRateCandidate(r)) return;

    final now = DateTime.now();
    final name = NearbyDevice.fixWindowsDeviceName(
      r.name.trim().isNotEmpty ? r.name : '未命名设备',
    );
    final id = r.id;

    final existingIndex = _nearby.indexWhere((d) => d.id == id);
    final isNew = existingIndex < 0;

    if (existingIndex >= 0) {
      _nearby[existingIndex]
        ..rssi = r.rssi
        ..connectable = r.connectable
        ..lastSeen = now;
    } else {
      _nearby.add(NearbyDevice(
        id: id,
        name: name,
        rssi: r.rssi,
        connectable: r.connectable,
        lastSeen: now,
      ));
      onLog('scan found: $name ($id) rssi=${r.rssi} connectable=${r.connectable}');
    }

    // Check for broadcast heart rate data
    _checkBroadcastHeartRate(r);

    // Notify about device
    onDeviceFound(_nearby.firstWhere((d) => d.id == id), isNew);
  }

  void _checkBroadcastHeartRate(BleDeviceInfo r) {
    final deviceName = NearbyDevice.fixWindowsDeviceName(r.name);
    
    if (isXiaomiDevice(deviceName)) {
      final serviceUuids = r.serviceUuids.join(', ');
      final serviceDataKeys = r.serviceData.keys.join(', ');
      final mfgData = r.manufacturerData;
      onLog('Xiaomi adv data: name=$deviceName, serviceUUIDs=[$serviceUuids], serviceDataKeys=[$serviceDataKeys], mfgDataLen=${mfgData.length}');
    }
    
    // Look for Heart Rate Service UUID (0x180D) in service data
    final data = r.serviceData[_heartRateServiceUuid] ?? 
                 r.serviceData[_heartRateServiceUuid.toLowerCase()] ??
                 r.serviceData[_heartRateServiceUuid.toUpperCase()];

    if (data == null || data.length < 2) return;

    final bpm = parseHeartRateValue(data);
    if (bpm == null) return;

    onLog('hr rx broadcast: bpm=$bpm rssi=${r.rssi} name=${r.name}');
    onBroadcastHeartRate(bpm, r.rssi, deviceName);
  }

  /// Parse heart rate value from BLE characteristic data
  static int? parseHeartRateValue(Uint8List data) {
    if (data.isEmpty) return null;

    final flags = data[0];
    final hr16 = (flags & 0x01) == 0x01;
    if (hr16 && data.length < 3) return null;

    return hr16 ? data[1] | (data[2] << 8) : data[1];
  }

  /// Extract broadcast heart rate from BLE device service data
  /// Returns the heart rate value if found in service data, null otherwise
  static int? extractBroadcastHeartRate(BleDeviceInfo r) {
    final data = r.serviceData[_heartRateServiceUuid] ?? 
                 r.serviceData[_heartRateServiceUuid.toLowerCase()] ??
                 r.serviceData[_heartRateServiceUuid.toUpperCase()];

    if (data == null || data.length < 2) return null;
    return parseHeartRateValue(data);
  }

  /// Prune devices not seen recently
  void pruneNearby() {
    final now = DateTime.now();
    _nearby.removeWhere((d) => now.difference(d.lastSeen) > nearbyTtl);
  }

  /// Sort devices by signal strength
  void sortByRssi() {
    _nearby.sort((a, b) => b.rssi.compareTo(a.rssi));
  }

  /// Clear all nearby devices
  void clearNearby() {
    _nearby.clear();
  }

  /// Check if device should be preferred for auto-connect
  static bool shouldPrefer(BleDeviceInfo r) {
    if (isLikelyPhoneOrPc(r)) return false;
    return isWearableHeartRateCandidate(r);
  }

  /// Select the best device for auto-connection
  NearbyDevice? selectPreferredDevice({String? savedDeviceId}) {
    if (_nearby.isEmpty) return null;
    
    // Prefer saved device if available
    if (savedDeviceId != null) {
      final saved = _nearby.where((d) => d.id == savedDeviceId).firstOrNull;
      if (saved != null && saved.connectable) return saved;
    }
    
    // Otherwise return the strongest connectable signal
    final connectable = _nearby.where((d) => d.connectable).toList();
    if (connectable.isEmpty) return null;
    
    connectable.sort((a, b) => b.rssi.compareTo(a.rssi));
    return connectable.first;
  }

  /// Detects if the device is a Xiaomi/Mi Band device
  static bool isXiaomiDevice(String name) {
    final lowerName = name.toLowerCase();
    return lowerName.contains('xiaomi') ||
        lowerName.contains('小米') ||
        lowerName.contains('mi band') ||
        lowerName.contains('mi smart band') ||
        lowerName.contains('miband') ||
        lowerName.contains('手环');
  }

  /// Check if device is likely a wearable heart rate device
  static bool isWearableHeartRateCandidate(BleDeviceInfo r) {
    final hasHeartRateService = r.serviceUuids
        .map((e) => e.toLowerCase())
        .any((id) => id.contains('180d'));
    
    final hasHeartRateServiceData = 
        r.serviceData.containsKey(_heartRateServiceUuid) ||
        r.serviceData.containsKey(_heartRateServiceUuid.toLowerCase());

    final name = r.name.toLowerCase();
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
        name.contains('小米') ||
        name.contains('miband') ||
        name.contains('mi band') ||
        name.contains('手环') ||
        name.contains('watch');

    return hasHeartRateService || hasHeartRateServiceData || likelyHrWearable;
  }

  /// Check if device is likely a phone or PC (not a wearable)
  static bool isLikelyPhoneOrPc(BleDeviceInfo r) {
    final name = r.name.toLowerCase();

    const phoneKeywords = [
      'iphone', 'ipad', 'android', 'pixel', 'samsung', 'galaxy',
      'huawei', 'honor', 'oneplus', 'oppo', 'vivo',
    ];

    const pcKeywords = [
      'macbook', 'mac ', 'imac', 'windows', 'pc', 
      'laptop', 'desktop', 'computer',
    ];

    const wearableKeywords = [
      'band', 'watch', 'hrm', 'heart', 'fit', 'wear',
      'miband', 'mi band', 'smart band', 'smartband',
      '小米', '手环', '手表',
    ];

    if (wearableKeywords.any(name.contains)) {
      return false;
    }
    return phoneKeywords.any(name.contains) || pcKeywords.any(name.contains);
  }
}
