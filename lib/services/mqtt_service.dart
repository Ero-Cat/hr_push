import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'dart:convert';

import '../app_log.dart';

/// MQTT Service for publishing heart rate data to MQTT broker
class MqttService {
  MqttService({
    required this.broker,
    required this.port,
    required this.topic,
    required this.username,
    required this.password,
    required this.clientId,
    this.onLog,
  });

  final String broker;
  final int port;
  final String topic;
  final String username;
  final String password;
  final String clientId;
  final void Function(String message, {Object? error})? onLog;

  MqttServerClient? _client;
  bool _connecting = false;
  bool _connected = false;

  bool get isEnabled => broker.trim().isNotEmpty && topic.trim().isNotEmpty;
  bool get isConnected => _connected;

  void _log(String message, {Object? error}) {
    onLog?.call(message, error: error);
    AppLog.info(message);
  }

  /// Send payload to MQTT broker
  Future<void> send(Map<String, dynamic> payload) async {
    if (!isEnabled) return;

    await _ensureConnected();
    final client = _client;
    if (client == null || !_connected) return;

    try {
      final builder = MqttClientPayloadBuilder();
      builder.addString(jsonEncode(payload));
      client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
      _log('mqtt published: $topic');
    } catch (e) {
      _log('mqtt publish failed: $topic', error: e);
      _connected = false;
      _client?.disconnect();
      _client = null;
    }
  }

  Future<void> _ensureConnected() async {
    if (_connected && _client != null) return;
    if (_connecting) return;

    _connecting = true;
    try {
      final brokerStr = broker.trim();
      if (brokerStr.isEmpty) return;
      
      var host = brokerStr;
      var actualPort = port > 0 ? port : 1883;
      
      if (brokerStr.contains('://')) {
        final uri = Uri.tryParse(brokerStr);
        if (uri != null && uri.host.isNotEmpty) {
          host = uri.host;
          if (port <= 0 && uri.port > 0) {
            actualPort = uri.port;
          }
        }
      }
      
      final usernameStr = username.trim();
      final rawClientId = clientId.trim();
      final actualClientId = rawClientId.isNotEmpty
          ? rawClientId
          : 'hr_push_${DateTime.now().millisecondsSinceEpoch}';

      _log('mqtt connecting: $host:$actualPort clientId=$actualClientId');
      
      final client = MqttServerClient(host, actualClientId)
        ..port = actualPort
        ..keepAlivePeriod = 20
        ..logging(on: false)
        ..onDisconnected = () {
          _log('mqtt disconnected: $host:$actualPort');
          _connected = false;
          _client = null;
        };

      final connMess = MqttConnectMessage()
          .withClientIdentifier(actualClientId)
          .withWillQos(MqttQos.atLeastOnce)
          .startClean();

      client.connectionMessage = connMess;

      try {
        await client.connect(
          usernameStr.isEmpty ? null : usernameStr,
          usernameStr.isEmpty ? null : password,
        );
      } catch (e) {
        _log('mqtt connect failed: $host:$actualPort', error: e);
        client.disconnect();
        return;
      }

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _client = client;
        _connected = true;
        _log('mqtt connected: $host:$actualPort');
      } else {
        client.disconnect();
      }
    } finally {
      _connecting = false;
    }
  }

  void dispose() {
    _client?.disconnect();
    _client = null;
    _connected = false;
  }
}
