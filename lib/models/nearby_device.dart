import 'dart:convert';
import 'dart:io' show Platform;

import '../ble/ble_adapter.dart';

/// Represents a nearby BLE device discovered during scanning
class NearbyDevice {
  NearbyDevice({
    required this.id,
    required this.name,
    required this.rssi,
    required this.connectable,
    required this.lastSeen,
  });

  final String id;
  final String name;
  int rssi;
  bool connectable;
  DateTime lastSeen;

  /// Create from BleDeviceInfo with automatic name fixing for Windows
  factory NearbyDevice.fromBleDevice(BleDeviceInfo device) {
    final fixedName = fixWindowsDeviceName(device.name);
    return NearbyDevice(
      id: device.id,
      name: fixedName,
      rssi: device.rssi,
      connectable: device.connectable,
      lastSeen: DateTime.now(),
    );
  }

  /// Fixes device name encoding issues on Windows.
  /// Windows Bluetooth stack may return device names as Latin-1 encoded UTF-8 bytes,
  /// causing garbled characters like `¿½` instead of Chinese characters.
  static String fixWindowsDeviceName(String name) {
    if (!Platform.isWindows) return name;
    if (name.isEmpty) return name;

    // Check if the name contains replacement characters or garbled patterns
    final hasGarbledChars = name.contains('¿') ||
        name.contains('½') ||
        name.contains('ï') ||
        name.codeUnits.any((c) => c >= 0x80 && c <= 0xFF);

    if (!hasGarbledChars) return name;

    try {
      // The name might be UTF-8 bytes interpreted as Latin-1.
      // Convert Latin-1 code units back to bytes, then decode as UTF-8.
      final bytes = name.codeUnits.map((c) => c & 0xFF).toList();
      final decoded = utf8.decode(bytes, allowMalformed: true);

      // If decoded contains actual valid characters (not just replacement chars),
      // and it's different from the original, use it.
      if (decoded != name && decoded.isNotEmpty && !decoded.contains('\uFFFD')) {
        return decoded;
      }
    } catch (_) {
      // Decoding failed, return original
    }

    return name;
  }
}
