import 'dart:io' show Platform;

import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import 'app_log.dart';

class HrNotificationService {
  static const _channel = MethodChannel('moe.iacg.hrpush/notification');

  HrNotificationService({bool Function()? isAndroid})
    : _isAndroid = isAndroid ?? (() => Platform.isAndroid);

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  final bool Function() _isAndroid;
  bool _initialized = false;

  Future<void> initialize() async {
    if (!_isAndroid() || _initialized) return;

    // We still use local_notifications for permission management for now
    // or just initialization if needed, but primary display is via MethodChannel.
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    _initialized = true;
  }

  Future<bool> ensurePermission() async {
    if (!_isAndroid()) return true;
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
    if (!_isAndroid()) return;
    try {
      await _channel.invokeMethod('updateNotification', {
        'bpm': 0,
        'deviceName': '',
        'isConnected': false,
        'status': status ?? '',
      });
    } catch (e) {
      _logError('updateNotification', e);
    }
  }

  Future<void> showConnected({
    required String deviceName,
    int? bpm,
    DateTime? lastUpdated,
    String? status,
  }) async {
    if (!_isAndroid()) return;
    try {
      await _channel.invokeMethod('updateNotification', {
        'bpm': bpm ?? 0,
        'deviceName': deviceName,
        'isConnected': true,
        'status': status ?? '',
      });
    } catch (e) {
      _logError('updateNotification', e);
    }
  }

  Future<bool> start() async {
    if (!_isAndroid()) return true;
    try {
      await _channel.invokeMethod('startForegroundService', {
        'bpm': 0,
        'deviceName': '',
        'isConnected': false,
      });
      return true;
    } catch (e) {
      _logError('startForegroundService', e);
      return false;
    }
  }

  Future<bool> openBackgroundRuntimeSettings() async {
    if (!_isAndroid()) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'openBackgroundRuntimeSettings',
          ) ??
          false;
    } catch (e) {
      _logError('openBackgroundRuntimeSettings', e);
      return false;
    }
  }

  Future<void> stop() async {
    if (!_isAndroid()) return;
    try {
      await _channel.invokeMethod('stopForegroundService');
    } catch (e) {
      _logError('stopForegroundService', e);
    }
  }

  Future<void> cancel() => stop();

  void _logError(String op, Object e) {
    // Route through AppLog so failures are visible in the in-app log viewer
    // instead of only in console output.
    AppLog.error('notification $op failed', error: e);
  }
}
