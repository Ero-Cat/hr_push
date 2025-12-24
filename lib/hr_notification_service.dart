import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class HrNotificationService {
  static const _channelId = 'hr_push_live';
  static const _channelName = '心率常驻通知';
  static const _channelDescription = '显示当前心率与连接状态';
  static const _notificationId = 1001;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (!Platform.isAndroid || _initialized) return;

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _plugin.initialize(initSettings);

    final androidImpl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (androidImpl != null) {
      const channel = AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: _channelDescription,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
        showBadge: false,
      );
      await androidImpl.createNotificationChannel(channel);
    }

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
    await _show(
      title: '未连接',
      body: status?.isNotEmpty == true ? status! : '等待心率设备连接',
    );
  }

  Future<void> showConnected({
    required String deviceName,
    int? bpm,
    DateTime? lastUpdated,
  }) async {
    if (!Platform.isAndroid) return;
    final displayName = deviceName.isEmpty ? '已连接' : deviceName;
    String body;
    if (bpm != null) {
      body = '$bpm BPM';
    } else {
      body = '已连接，等待数据';
    }
    if (lastUpdated != null) {
      final delta = DateTime.now().difference(lastUpdated);
      final seconds = delta.inSeconds.clamp(0, 9999);
      body = '$body · ${seconds}s 前更新';
    }

    await _show(title: displayName, body: body);
  }

  Future<void> cancel() async {
    if (!Platform.isAndroid) return;
    try {
      await _plugin.cancel(_notificationId);
    } catch (_) {}
  }

  Future<void> _show({required String title, required String body}) async {
    if (!_initialized) {
      try {
        await initialize();
      } catch (_) {
        return;
      }
    }

    final androidDetails = AndroidNotificationDetails(
      _channelId,
      _channelName,
      channelDescription: _channelDescription,
      importance: Importance.low,
      priority: Priority.low,
      ongoing: true,
      onlyAlertOnce: true,
      showWhen: false,
      autoCancel: false,
      color: const Color(0xFFFF375F),
      colorized: true,
      category: AndroidNotificationCategory.service,
      visibility: NotificationVisibility.public,
      styleInformation: BigTextStyleInformation(
        body,
        contentTitle: title,
        summaryText: '心率常驻',
      ),
    );

    final details = NotificationDetails(android: androidDetails);
    try {
      await _plugin.show(_notificationId, title, body, details);
    } catch (_) {}
  }
}
