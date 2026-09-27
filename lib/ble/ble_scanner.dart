import 'dart:typed_data';

import '../models/nearby_device.dart';
import 'ble_adapter.dart';

/// BLE device scanning and identification service
class BleScanner {
  BleScanner({required this.onLog, required this.onBroadcastHeartRate});

  final void Function(String message, {Object? error}) onLog;
  final void Function(int bpm, int rssi, String deviceName)
  onBroadcastHeartRate;

  final List<NearbyDevice> _nearby = [];

  /// Cached unmodifiable view of [_nearby]. Rebuilding it on every mutation
  /// (instead of on every getter call) keeps the instance stable between
  /// changes so UI selectors can compare by identity.
  List<NearbyDevice> _nearbyView = List.unmodifiable(const <NearbyDevice>[]);

  static const Duration nearbyTtl = Duration(seconds: 15);
  static const String _heartRateServiceUuid =
      '0000180d-0000-1000-8000-00805f9b34fb';

  /// Xiaomi/Redmi wearables: rotate their MAC address and require the
  /// on-device "Heart Rate Broadcast" toggle before exposing the standard
  /// heart rate service.
  static const List<String> _xiaomiKeywords = [
    'xiaomi',
    'redmi',
    '小米',
    'mi band',
    'mi smart band',
    'miband',
    '手环',
  ];

  List<NearbyDevice> get nearbyDevices => _nearbyView;

  void _refreshNearbyView() {
    _nearbyView = List.unmodifiable(_nearby);
  }

  /// Handle a scan result from BLE adapter
  void handleScanResult(BleDeviceInfo r) {
    if (isLikelyPhoneOrPc(r)) return;
    if (!isWearableHeartRateCandidate(r)) return;

    final now = DateTime.now();
    // Keep the name empty when the device did not advertise one; the UI
    // layer renders a localized "Unknown device (xxxx)" label instead.
    final name = NearbyDevice.fixWindowsDeviceName(r.name.trim());
    final id = r.id;

    final existingIndex = _nearby.indexWhere((d) => d.id == id);

    if (existingIndex >= 0) {
      _nearby[existingIndex]
        ..rssi = r.rssi
        ..connectable = r.connectable
        ..lastSeen = now;
    } else {
      _nearby.add(
        NearbyDevice(
          id: id,
          name: name,
          rssi: r.rssi,
          connectable: r.connectable,
          lastSeen: now,
        ),
      );
      onLog(
        'scan found: $name ($id) rssi=${r.rssi} connectable=${r.connectable}',
      );
    }

    // Check for broadcast heart rate data
    _checkBroadcastHeartRate(r);
    _refreshNearbyView();
  }

  void _checkBroadcastHeartRate(BleDeviceInfo r) {
    final deviceName = NearbyDevice.fixWindowsDeviceName(r.name);

    if (isXiaomiDevice(deviceName)) {
      final serviceUuids = r.serviceUuids.join(', ');
      final serviceDataKeys = r.serviceData.keys.join(', ');
      final mfgData = r.manufacturerData;
      onLog(
        'Xiaomi adv data: name=$deviceName, serviceUUIDs=[$serviceUuids], serviceDataKeys=[$serviceDataKeys], mfgDataLen=${mfgData.length}',
      );
    }

    // Look for Heart Rate Service UUID (0x180D) in service data
    final data =
        r.serviceData[_heartRateServiceUuid] ??
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

  /// Prune devices not seen recently
  void pruneNearby() {
    final now = DateTime.now();
    final before = _nearby.length;
    _nearby.removeWhere((d) => now.difference(d.lastSeen) > nearbyTtl);
    if (_nearby.length != before) _refreshNearbyView();
  }

  /// Sort devices by signal strength
  void sortByRssi() {
    _nearby.sort((a, b) => b.rssi.compareTo(a.rssi));
    _refreshNearbyView();
  }

  /// Clear all nearby devices
  void clearNearby() {
    _nearby.clear();
    _refreshNearbyView();
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

  /// Detects if the device is a Xiaomi/Redmi wearable (see
  /// [_xiaomiKeywords] for why these get special treatment).
  static bool isXiaomiDevice(String name) {
    final lowerName = name.toLowerCase();
    return _xiaomiKeywords.any(lowerName.contains);
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
    const brandKeywords = [
      'garmin',
      'enduro',
      'hrm',
      'polar',
      'wahoo',
      'coros',
      'suunto',
      'fitbit',
      'watch',
    ];
    final likelyHrWearable =
        brandKeywords.any(name.contains) || isXiaomiDevice(r.name);

    return hasHeartRateService || hasHeartRateServiceData || likelyHrWearable;
  }

  /// Check if device is likely a phone or PC (not a wearable)
  static bool isLikelyPhoneOrPc(BleDeviceInfo r) {
    final name = r.name.toLowerCase();

    const phoneKeywords = [
      'iphone',
      'ipad',
      'android',
      'pixel',
      'samsung',
      'galaxy',
      'huawei',
      'honor',
      'oneplus',
      'oppo',
      'vivo',
    ];

    const pcKeywords = [
      'macbook',
      'mac ',
      'imac',
      'windows',
      'pc',
      'laptop',
      'desktop',
      'computer',
    ];

    const wearableKeywords = [
      'band',
      'watch',
      'hrm',
      'heart',
      'fit',
      'wear',
      'miband',
      'mi band',
      'smart band',
      'smartband',
      '小米',
      '手环',
      '手表',
    ];

    if (wearableKeywords.any(name.contains)) {
      return false;
    }
    return phoneKeywords.any(name.contains) || pcKeywords.any(name.contains);
  }
}
