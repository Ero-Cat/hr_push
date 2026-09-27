import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/services/mqtt_service.dart';

void main() {
  group('resolveBroker', () {
    test('bare host keeps the configured port', () {
      final r = MqttService.resolveBroker('broker.example.com', 1884);
      expect(r.host, 'broker.example.com');
      expect(r.effectivePort, 1884);
      expect(r.tlsFromScheme, isFalse);
    });

    test('bare host falls back to 1883 without an explicit port', () {
      final r = MqttService.resolveBroker('broker.example.com', 0);
      expect(r.effectivePort, 1883);
    });

    test('mqtt:// URI extracts the host without TLS', () {
      final r = MqttService.resolveBroker('mqtt://broker.example.com', 0);
      expect(r.host, 'broker.example.com');
      expect(r.tlsFromScheme, isFalse);
      expect(r.effectivePort, 1883);
    });

    test('mqtts:// URI enables TLS and defaults to 8883', () {
      final r = MqttService.resolveBroker('mqtts://broker.example.com', 0);
      expect(r.tlsFromScheme, isTrue);
      expect(r.effectivePort, 8883);
    });

    test('URI port is used only when no explicit port is set', () {
      final fromUri = MqttService.resolveBroker(
        'mqtt://broker.example.com:1234',
        0,
      );
      expect(fromUri.effectivePort, 1234);

      final explicit = MqttService.resolveBroker(
        'mqtt://broker.example.com:1234',
        999,
      );
      expect(explicit.effectivePort, 999);
    });
  });

  test('send is a no-op when disabled', () async {
    final logs = <String>[];
    final service = MqttService(
      broker: '',
      port: 1883,
      topic: 'hr_push',
      username: '',
      password: '',
      clientId: '',
      onLog: (m, {error}) => logs.add(m),
    );
    addTearDown(service.dispose);

    await service.send({'heart_rate': 88});

    expect(service.isConnected, isFalse);
    expect(logs, isEmpty);
  });

  test(
    'connect failure is contained and reported',
    () async {
      // Port on loopback with nothing listening.
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final deadPort = server.port;
      await server.close(force: true);

      final logs = <String>[];
      final service = MqttService(
        broker: '127.0.0.1',
        port: deadPort,
        topic: 'hr_push',
        username: '',
        password: '',
        clientId: 'test-client',
        onLog: (m, {error}) => logs.add(m),
      );
      addTearDown(service.dispose);

      await service.send({'heart_rate': 88});

      expect(service.isConnected, isFalse);
      expect(logs.any((l) => l.contains('mqtt connect failed')), isTrue);
    },
    timeout: const Timeout(Duration(seconds: 30)),
  );
}
