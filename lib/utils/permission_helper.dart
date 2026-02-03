import 'dart:io' show Platform;

import 'package:permission_handler/permission_handler.dart';

import '../ble/ble_adapter.dart';

/// Result of permission and Bluetooth check
class PermissionCheckResult {
  const PermissionCheckResult({
    required this.success,
    this.errorMessage,
  });

  final bool success;
  final String? errorMessage;

  static const ok = PermissionCheckResult(success: true);
  
  factory PermissionCheckResult.error(String message) =>
      PermissionCheckResult(success: false, errorMessage: message);
}

/// Helper for managing permissions and Bluetooth state
class PermissionHelper {
  PermissionHelper({
    required BleAdapter bleAdapter,
    required this.onLog,
  }) : _bleAdapter = bleAdapter;

  final BleAdapter _bleAdapter;
  final void Function(String message) onLog;

  /// Check if current platform supports BLE
  static bool get isBleSupportedPlatform =>
      Platform.isAndroid || Platform.isIOS || Platform.isWindows || Platform.isMacOS;

  /// Check permissions and Bluetooth availability
  Future<PermissionCheckResult> ensurePermissionsAndBluetooth() async {
    if (!isBleSupportedPlatform) {
      return PermissionCheckResult.error('当前平台暂不支持蓝牙');
    }

    if (!await _bleAdapter.isBluetoothAvailable()) {
      return PermissionCheckResult.error('蓝牙不可用');
    }

    if (Platform.isAndroid) {
      final result = await _requestAndroidPermissions();
      if (!result.success) return result;
    }

    onLog('permissions ok, adapter ready');
    return PermissionCheckResult.ok;
  }

  Future<PermissionCheckResult> _requestAndroidPermissions() async {
    final androidVersion = androidMajorVersion;
    final needsLocation = androidVersion != null && androidVersion <= 11;

    final requests = <Permission>[
      Permission.bluetoothScan,
      Permission.bluetoothConnect,
      if (needsLocation) Permission.location,
    ];

    final results = await requests.request();

    final denied = results.values.any(
      (s) => s.isDenied || s.isPermanentlyDenied || s.isRestricted,
    );
    
    if (denied) {
      return PermissionCheckResult.error('蓝牙/定位权限未授予');
    }
    
    return PermissionCheckResult.ok;
  }

  /// Get Android major version from system info
  static int? get androidMajorVersion {
    if (!Platform.isAndroid) return null;
    final match = RegExp(r'Android (\d+)').firstMatch(Platform.operatingSystemVersion);
    if (match == null) return null;
    return int.tryParse(match.group(1)!);
  }
}
