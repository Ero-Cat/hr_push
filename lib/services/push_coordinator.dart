import 'dart:async';

import '../models/heart_rate_settings.dart';
import 'http_ws_service.dart';
import 'mqtt_service.dart';
import 'osc_service.dart';

enum OscSendState { disabled, ready, sent, acknowledged, error }

class OscStatus {
  const OscStatus({
    required this.state,
    required this.target,
    required this.message,
    required this.updatedAt,
  });

  factory OscStatus.disabled() {
    return const OscStatus(
      state: OscSendState.disabled,
      target: '',
      message: '',
      updatedAt: null,
    );
  }

  factory OscStatus.ready(String target) {
    return OscStatus(
      state: OscSendState.ready,
      target: target,
      message: '',
      updatedAt: null,
    );
  }

  factory OscStatus.sent(String target) {
    return OscStatus(
      state: OscSendState.sent,
      target: target,
      message: '',
      updatedAt: DateTime.now(),
    );
  }

  factory OscStatus.acknowledged(String target) {
    return OscStatus(
      state: OscSendState.acknowledged,
      target: target,
      message: '',
      updatedAt: DateTime.now(),
    );
  }

  factory OscStatus.error(String target, String message) {
    return OscStatus(
      state: OscSendState.error,
      target: target,
      message: message,
      updatedAt: DateTime.now(),
    );
  }

  final OscSendState state;
  final String target;
  final String message;
  final DateTime? updatedAt;
}

/// Coordinates all push services (HTTP/WebSocket, MQTT, OSC)
/// Provides a unified interface for sending heart rate data to all configured endpoints
class PushCoordinator {
  PushCoordinator({
    required this.onLog,
    this.onOscStatusChanged,
    this.oscAcknowledgementTimeout = const Duration(milliseconds: 800),
  });

  final void Function(String message, {Object? error}) onLog;
  final void Function(OscStatus status)? onOscStatusChanged;
  final Duration oscAcknowledgementTimeout;

  HttpWsService? _httpWsService;
  MqttService? _mqttService;
  OscService? _oscService;
  OscStatus _oscStatus = OscStatus.disabled();

  HeartRateSettings _settings = HeartRateSettings.defaults();

  OscStatus get oscStatus => _oscStatus;

  /// Update settings and recreate services if needed
  void updateSettings(HeartRateSettings value) {
    final old = _settings;
    _settings = value;

    // Reset HTTP/WS service if endpoint changed
    if (old.pushEndpoint != value.pushEndpoint) {
      _httpWsService?.dispose();
      _httpWsService = null;
    }

    // Reset OSC service if any OSC setting changed. OscService stores paths
    // and ChatBox options in final fields, so keeping the instance would keep
    // sending with stale settings until app restart.
    final oscChanged =
        old.oscAddress != value.oscAddress ||
        old.oscHrConnectedPath != value.oscHrConnectedPath ||
        old.oscHrValuePath != value.oscHrValuePath ||
        old.oscHrPercentPath != value.oscHrPercentPath ||
        old.oscChatboxEnabled != value.oscChatboxEnabled ||
        old.oscChatboxTemplate != value.oscChatboxTemplate;
    if (oscChanged) {
      _oscService?.dispose();
      _oscService = null;
    }
    _setOscConfiguredStatus(value);

    // Reset MQTT service if any MQTT settings changed
    final mqttChanged =
        old.mqttBroker != value.mqttBroker ||
        old.mqttPort != value.mqttPort ||
        old.mqttTopic != value.mqttTopic ||
        old.mqttUsername != value.mqttUsername ||
        old.mqttPassword != value.mqttPassword ||
        old.mqttClientId != value.mqttClientId;
    if (mqttChanged) {
      _mqttService?.dispose();
      _mqttService = null;
    }
  }

  /// Send heart rate data to all configured push endpoints
  Future<void> sendHeartRate({
    required int bpm,
    required double? percent,
    required DateTime timestamp,
  }) async {
    final payload = {
      'heart_rate': bpm,
      'timestamp': timestamp.toIso8601String(),
      if (percent != null) 'percent': percent,
    };

    // HTTP/WebSocket push
    await _sendHttpWs(payload);

    // MQTT push
    await _sendMqtt(payload);

    // OSC push
    await _sendOscHeartRate(bpm, percent);
  }

  /// Send connection status via OSC
  Future<void> sendConnectionStatus(
    bool connected, {
    bool force = false,
  }) async {
    if (_settings.oscAddress.trim().isEmpty) {
      _setOscStatus(OscStatus.disabled());
      return;
    }
    await _sendOsc(
      (service) => service.sendConnectedStatus(connected, force: force),
    );
  }

  /// Send chatbox message via OSC (for VRChat)
  Future<void> sendChatbox(int bpm, double? percent) async {
    if (_settings.oscAddress.trim().isEmpty) {
      _setOscStatus(OscStatus.disabled());
      return;
    }
    if (!_settings.oscChatboxEnabled) return;
    await _sendOsc((service) => service.sendChatbox(bpm, percent));
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Private methods
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> _sendHttpWs(Map<String, dynamic> payload) async {
    final endpoint = _settings.pushEndpoint.trim();
    if (endpoint.isEmpty) return;

    _httpWsService ??= HttpWsService(endpoint: endpoint, onLog: onLog);
    await _httpWsService!.send(payload);
  }

  Future<void> _sendMqtt(Map<String, dynamic> payload) async {
    final broker = _settings.mqttBroker.trim();
    if (broker.isEmpty) return;

    _mqttService ??= MqttService(
      broker: broker,
      port: _settings.mqttPort,
      topic: _settings.mqttTopic,
      username: _settings.mqttUsername,
      password: _settings.mqttPassword,
      clientId: _settings.mqttClientId,
      onLog: onLog,
    );
    await _mqttService!.send(payload);
  }

  Future<void> _sendOscHeartRate(int bpm, double? percent) async {
    if (_settings.oscAddress.trim().isEmpty) {
      _setOscStatus(OscStatus.disabled());
      return;
    }
    await _sendOsc((service) => service.sendHeartRate(bpm, percent));
  }

  OscService _getOscService() {
    return _oscService ??= OscService(
      oscAddress: _settings.oscAddress,
      hrConnectedPath: _settings.oscHrConnectedPath,
      hrValuePath: _settings.oscHrValuePath,
      hrPercentPath: _settings.oscHrPercentPath,
      chatboxEnabled: _settings.oscChatboxEnabled,
      chatboxTemplate: _settings.oscChatboxTemplate,
      onLog: onLog,
    );
  }

  Future<void> _sendOsc(Future<bool> Function(OscService service) send) async {
    final target = _settings.oscAddress.trim();
    final service = _getOscService();
    try {
      final ok = await send(service);
      if (!ok) {
        _setOscStatus(
          OscStatus.error(target, 'OSC target or socket unavailable'),
        );
        return;
      }
      _setOscStatus(OscStatus.sent(target));
      unawaited(_requestOscAcknowledgement(service, target));
    } catch (e) {
      _setOscStatus(OscStatus.error(target, e.toString()));
    }
  }

  Future<void> _requestOscAcknowledgement(
    OscService service,
    String target,
  ) async {
    final ok = await service.requestAcknowledgement(
      timeout: oscAcknowledgementTimeout,
    );
    if (!ok) return;
    if (_settings.oscAddress.trim() != target) return;
    if (_oscStatus.target != target) return;
    _setOscStatus(OscStatus.acknowledged(target));
  }

  void _setOscConfiguredStatus(HeartRateSettings value) {
    final target = value.oscAddress.trim();
    if (target.isEmpty) {
      _setOscStatus(OscStatus.disabled());
      return;
    }
    _setOscStatus(OscStatus.ready(target));
  }

  void _setOscStatus(OscStatus status) {
    _oscStatus = status;
    onOscStatusChanged?.call(status);
  }

  /// Dispose all services
  void dispose() {
    _httpWsService?.dispose();
    _mqttService?.dispose();
    _oscService?.dispose();
    _httpWsService = null;
    _mqttService = null;
    _oscService = null;
  }
}
