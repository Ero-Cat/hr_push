import '../models/heart_rate_settings.dart';
import 'http_ws_service.dart';
import 'mqtt_service.dart';
import 'osc_service.dart';

/// Coordinates all push services (HTTP/WebSocket, MQTT, OSC)
/// Provides a unified interface for sending heart rate data to all configured endpoints
class PushCoordinator {
  PushCoordinator({required this.onLog});

  final void Function(String message, {Object? error}) onLog;

  HttpWsService? _httpWsService;
  MqttService? _mqttService;
  OscService? _oscService;

  HeartRateSettings _settings = HeartRateSettings.defaults();

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
    if (_settings.oscAddress.trim().isEmpty) return;
    await _getOscService().sendConnectedStatus(connected, force: force);
  }

  /// Send chatbox message via OSC (for VRChat)
  Future<void> sendChatbox(int bpm, double? percent) async {
    if (_settings.oscAddress.trim().isEmpty) return;
    await _getOscService().sendChatbox(bpm, percent);
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
    if (_settings.oscAddress.trim().isEmpty) return;
    await _getOscService().sendHeartRate(bpm, percent);
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
