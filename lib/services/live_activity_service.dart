import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:live_activities/live_activities.dart';

import '../app_log.dart';

/// iOS 16.1+ Live Activity (lock-screen / Dynamic Island heart rate).
///
/// The widget extension (`ios/LiveActivitiesExtension`) renders the activity;
/// this service feeds it from Dart via the live_activities plugin. Updates
/// are throttled by the caller (the HR publish interval).
class LiveActivityService {
  LiveActivityService({bool Function()? isIOS})
    : _isIOS = isIOS ?? (() => !kIsWeb && Platform.isIOS);

  static const _activityKey = 'hr-live-activity';

  final bool Function() _isIOS;
  final LiveActivities _plugin = LiveActivities();

  String? _activityId;
  bool _initialized = false;
  String? _lastStatus;

  bool get _available {
    if (!_isIOS()) return false;
    return _initialized;
  }

  Future<void> initialize() async {
    if (!_isIOS() || _initialized) return;
    try {
      final supported = await _plugin.areActivitiesSupported();
      if (!supported) return;
      // The extension reads state directly (no App Group data transfer), so
      // an empty group id is fine. Remote (push) updates stay disabled to
      // avoid requiring the Push Notifications capability.
      await _plugin.init(appGroupId: '');
      _initialized = true;
    } catch (e) {
      AppLog.info('live activity init failed: $e');
    }
  }

  /// Create or update the activity with the latest heart rate.
  Future<void> update({required int bpm, required String status}) async {
    if (!_available) return;
    if (_activityId == null && status == _lastStatus && bpm <= 0) return;
    try {
      final data = <String, dynamic>{
        'bpm': bpm,
        'status': status,
        'updatedAt': DateTime.now().millisecondsSinceEpoch,
      };
      if (_activityId == null) {
        _activityId = await _plugin.createActivity(
          _activityKey,
          data,
          removeWhenAppIsKilled: true,
          iOSEnableRemoteUpdates: false,
        );
      } else {
        await _plugin.updateActivity(_activityId!, data);
      }
      _lastStatus = status;
    } catch (e) {
      AppLog.info('live activity update failed: $e');
    }
  }

  /// End the activity (device disconnected).
  Future<void> end() async {
    final id = _activityId;
    _activityId = null;
    _lastStatus = null;
    if (!_available || id == null) return;
    try {
      await _plugin.endActivity(id);
    } catch (e) {
      AppLog.info('live activity end failed: $e');
    }
  }

  void dispose() {
    final id = _activityId;
    _activityId = null;
    if (!_available || id == null) return;
    try {
      _plugin.endActivity(id);
    } catch (_) {}
  }
}
