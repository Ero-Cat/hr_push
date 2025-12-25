import 'dart:io' show Platform;


import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HrNotificationService {
  static const _channel = MethodChannel('moe.iacg.hrpush/notification');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;

    // We still use local_notifications for permission management for now
    // or just initialization if needed, but primary display is via MethodChannel.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  Future<bool> ensurePermission() async {
    if (!Platform.isAndroid) return true;
    if (!_initialized) {
      await initialize();
    }
    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl == null) return true;
    try {
      final granted = await androidImpl.requestNotificationsPermission();
      return granted ?? true;
    } catch (_) {
      return false;
    }
  }

  Future<void> showDisconnected({String? status}) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateNotification', {
        'bpm': 0,
        'deviceName': '',
        'isConnected': false,
      });
    } catch (e) {
      debugPrint('Error updating notification: $e');
    }
  }

  Future<void> showConnected({
    required String deviceName,
    int? bpm,
    DateTime? lastUpdated,
  }) async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('updateNotification', {
        'bpm': bpm ?? 0,
        'deviceName': deviceName,
        'isConnected': true,
      });
    } catch (e) {
      debugPrint('Error updating notification: $e');
    }
  }

  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('cancelNotification');
    } catch (_) {}
  }
}
