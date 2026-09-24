import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:http/http.dart' as http;
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'package:web_socket_channel/io.dart';

import '../app_log.dart';
import '../models/heart_rate_settings.dart';
import 'mqtt_service.dart';

enum ConnectionTestState { running, ok, failed }

class ConnectionTestResult {
  const ConnectionTestResult({required this.state, required this.detail});

  const ConnectionTestResult.ok(String detail)
    : this(state: ConnectionTestState.ok, detail: detail);

  const ConnectionTestResult.failed(String detail)
    : this(state: ConnectionTestState.failed, detail: detail);

  final ConnectionTestState state;
  final String detail;
  bool get isOk => state == ConnectionTestState.ok;
}

/// One-shot connectivity probes for each push protocol, used by the
/// "Test" buttons in the settings page.
class ConnectionTester {
  ConnectionTester._();

  static const _timeout = Duration(seconds: 5);

  static Map<String, dynamic> _testPayload() => {
    'event': 'test',
    'heart_rate': 0,
    'timestamp': DateTime.now().toIso8601String(),
  };

  /// POST a test payload to an http(s) endpoint.
  static Future<ConnectionTestResult> testHttp(String endpoint) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || uri.host.isEmpty) {
      return const ConnectionTestResult.failed('invalid endpoint');
    }
    try {
      final response = await http
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(_testPayload()),
          )
          .timeout(_timeout);
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ConnectionTestResult.ok('HTTP ${response.statusCode}');
      }
      return ConnectionTestResult.failed('HTTP ${response.statusCode}');
    } catch (e) {
      AppLog.info('test http failed: $e');
      return ConnectionTestResult.failed(e.toString());
    }
  }

  /// Open a WebSocket, send a test frame, and wait for the handshake.
  static Future<ConnectionTestResult> testWebSocket(String endpoint) async {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null || uri.host.isEmpty) {
      return const ConnectionTestResult.failed('invalid endpoint');
    }
    IOWebSocketChannel? channel;
    try {
      channel = IOWebSocketChannel.connect(uri);
      await channel.ready.timeout(_timeout);
      channel.sink.add(jsonEncode(_testPayload()));
      return const ConnectionTestResult.ok('websocket connected');
    } catch (e) {
      AppLog.info('test ws failed: $e');
      return ConnectionTestResult.failed(e.toString());
    } finally {
      await channel?.sink.close().timeout(
        const Duration(seconds: 2),
        onTimeout: () {},
      );
    }
  }

  /// Resolve an OSC target and send a harmless OSC message over UDP.
  ///
  /// UDP has no delivery receipt; success only proves the target resolved
  /// and the datagram left the socket.
  static Future<ConnectionTestResult> testOsc(String address) async {
    final trimmed = address.trim();
    final uri = Uri.tryParse('scheme://$trimmed');
    if (uri == null || uri.host.isEmpty || uri.port <= 0) {
      return const ConnectionTestResult.failed('invalid address');
    }
    RawDatagramSocket? socket;
    try {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        0,
      ).timeout(_timeout);
      final data = _encodeOscMessage('/hr_push/test', [1]);
      final sent = socket.send(data, InternetAddress(uri.host), uri.port);
      if (sent <= 0) {
        return const ConnectionTestResult.failed('datagram not sent');
      }
      return ConnectionTestResult.ok('sent to ${uri.host}:${uri.port}');
    } catch (e) {
      AppLog.info('test osc failed: $e');
      return ConnectionTestResult.failed(e.toString());
    } finally {
      socket?.close();
    }
  }

  /// Connect to the MQTT broker and disconnect immediately.
  static Future<ConnectionTestResult> testMqtt(
    HeartRateSettings settings, {
    bool useTlsOverride = false,
  }) async {
    final resolved = MqttService.resolveBroker(
      settings.mqttBroker,
      settings.mqttPort,
    );
    final tls = useTlsOverride || settings.mqttUseTls || resolved.tlsFromScheme;
    if (resolved.host.isEmpty) {
      return const ConnectionTestResult.failed('broker is empty');
    }

    final client = MqttServerClient(resolved.host, 'hr_push_test')
      ..port = resolved.effectivePort
      ..keepAlivePeriod = 10
      ..logging(on: false)
      ..connectTimeoutPeriod = _timeout.inMilliseconds;
    if (tls) {
      client.secure = true;
    }
    client.connectionMessage = MqttConnectMessage()
        .withClientIdentifier('hr_push_test')
        .startClean();

    try {
      final username = settings.mqttUsername.trim();
      await client
          .connect(
            username.isEmpty ? null : username,
            username.isEmpty ? null : settings.mqttPassword,
          )
          .timeout(_timeout);
      final state = client.connectionStatus?.state;
      client.disconnect();
      if (state == MqttConnectionState.connected) {
        return ConnectionTestResult.ok(
          'connected to ${resolved.host}:${resolved.effectivePort}'
          '${tls ? ' (TLS)' : ''}',
        );
      }
      return ConnectionTestResult.failed('state: $state');
    } catch (e) {
      client.disconnect();
      AppLog.info('test mqtt failed: $e');
      return ConnectionTestResult.failed(e.toString());
    }
  }

  /// Minimal OSC 1.0 encoding: address + typetags + int args, 4-byte padded.
  static Uint8List _encodeOscMessage(String address, List<int> intArgs) {
    final bytes = <int>[];
    void addPaddedString(String s) {
      final encoded = utf8.encode(s);
      bytes.addAll(encoded);
      final pad = 4 - (encoded.length % 4);
      bytes.addAll(List.filled(pad == 4 ? 0 : pad, 0));
    }

    addPaddedString(address);
    addPaddedString(',${'i' * intArgs.length}');
    for (final arg in intArgs) {
      final value = arg.toSigned(32);
      bytes
        ..add((value >> 24) & 0xFF)
        ..add((value >> 16) & 0xFF)
        ..add((value >> 8) & 0xFF)
        ..add(value & 0xFF);
    }
    return Uint8List.fromList(bytes);
  }
}
