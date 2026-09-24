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
    this.useTls = false,
    this.lwtTopic = '',
    this.onLog,
  });

  final String broker;
  final int port;
  final String topic;
  final String username;
  final String password;
  final String clientId;
  final bool useTls;
  final String lwtTopic;
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

  /// Resolve broker host/port from a bare host or a mqtt://host:port URI.
  static ({String host, int effectivePort, bool tlsFromScheme}) resolveBroker(
    String broker,
    int port,
  ) {
    var host = broker.trim();
    var effectivePort = port > 0 ? port : 1883;
    var tlsFromScheme = false;

    if (broker.contains('://')) {
      final uri = Uri.tryParse(broker.trim());
      if (uri != null && uri.host.isNotEmpty) {
        host = uri.host;
        tlsFromScheme =
            uri.scheme == 'mqtts' || uri.scheme == 'tls' || uri.scheme == 'ssl';
        if (port <= 0 && uri.port > 0) {
          effectivePort = uri.port;
        }
        if (tlsFromScheme && port <= 0) {
          effectivePort = uri.port > 0 ? uri.port : 8883;
        }
      }
    }
    return (
      host: host,
      effectivePort: effectivePort,
      tlsFromScheme: tlsFromScheme,
    );
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
    if (_connecting) {
      _log('mqtt busy connecting, payload dropped');
      return;
    }

    _connecting = true;
    try {
      final brokerStr = broker.trim();
      if (brokerStr.isEmpty) return;

      final resolved = resolveBroker(broker, port);
      final tls = useTls || resolved.tlsFromScheme;

      final usernameStr = username.trim();
      final rawClientId = clientId.trim();
      final actualClientId = rawClientId.isNotEmpty ? rawClientId : 'hr_push';

      _log(
        'mqtt connecting: ${resolved.host}:${resolved.effectivePort}'
        ' tls=$tls clientId=$actualClientId',
      );

      final client = MqttServerClient(resolved.host, actualClientId)
        ..port = resolved.effectivePort
        ..keepAlivePeriod = 20
        ..logging(on: false)
        ..onDisconnected = () {
          _log('mqtt disconnected: ${resolved.host}:${resolved.effectivePort}');
          _connected = false;
          _client = null;
        };
      if (tls) {
        client.secure = true;
      }

      final connMess = MqttConnectMessage().withClientIdentifier(
        actualClientId,
      );
      final lwt = lwtTopic.trim();
      if (lwt.isNotEmpty) {
        connMess
          ..withWillTopic(lwt)
          ..withWillMessage(
            jsonEncode({
              'event': 'connection',
              'connected': false,
              'timestamp': DateTime.now().toIso8601String(),
            }),
          )
          ..withWillQos(MqttQos.atLeastOnce);
      } else {
        connMess.withWillQos(MqttQos.atLeastOnce);
      }
      connMess.startClean();

      client.connectionMessage = connMess;

      try {
        await client.connect(
          usernameStr.isEmpty ? null : usernameStr,
          usernameStr.isEmpty ? null : password,
        );
      } catch (e) {
        _log(
          'mqtt connect failed: ${resolved.host}:${resolved.effectivePort}',
          error: e,
        );
        client.disconnect();
        return;
      }

      if (client.connectionStatus?.state == MqttConnectionState.connected) {
        _client = client;
        _connected = true;
        _log('mqtt connected: ${resolved.host}:${resolved.effectivePort}');
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
