import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/services/http_ws_service.dart';

void main() {
  test('ws backoff grows exponentially and caps at 30s', () {
    expect(HttpWsService.backoffSecondsFor(0), 0);
    expect(HttpWsService.backoffSecondsFor(1), 1);
    expect(HttpWsService.backoffSecondsFor(2), 2);
    expect(HttpWsService.backoffSecondsFor(3), 4);
    expect(HttpWsService.backoffSecondsFor(4), 8);
    expect(HttpWsService.backoffSecondsFor(5), 16);
    expect(HttpWsService.backoffSecondsFor(6), 30);
    expect(HttpWsService.backoffSecondsFor(12), 30);
  });

  test(
    'http send posts the JSON payload and reports the status code',
    () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      final received = <Map<String, dynamic>>[];
      final statuses = <int>[];
      final sub = server.listen((request) async {
        final bytes = <int>[];
        await for (final chunk in request) {
          bytes.addAll(chunk);
        }
        received.add(jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>);
        statuses.add(request.response.statusCode);
        request.response.write('ok');
        await request.response.close();
      });
      addTearDown(() async {
        await sub.cancel();
        await server.close(force: true);
      });

      final logs = <String>[];
      final service = HttpWsService(
        endpoint: 'http://127.0.0.1:${server.port}/hook',
        onLog: (m, {error}) => logs.add(m),
      );
      addTearDown(service.dispose);

      await service.send({
        'event': 'heartRate',
        'heart_rate': 88,
        'heartRate': 88,
        'connected': true,
        'timestamp': DateTime.now().toIso8601String(),
      });

      expect(received, hasLength(1));
      expect(received.first['heart_rate'], 88);
      expect(received.first['heartRate'], 88);
      expect(received.first['event'], 'heartRate');
      expect(received.first['connected'], isTrue);
      expect(received.first['timestamp'], isA<String>());
      expect(logs.any((l) => l.contains('push http 200')), isTrue);
    },
  );

  test('http failure is contained and does not throw', () async {
    // Port on loopback with nothing listening.
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final deadPort = server.port;
    await server.close(force: true);

    final logs = <String>[];
    final service = HttpWsService(
      endpoint: 'http://127.0.0.1:$deadPort/hook',
      onLog: (m, {error}) => logs.add(m),
    );
    addTearDown(service.dispose);

    await service.send({'heart_rate': 88});

    expect(logs.any((l) => l.contains('push http failed')), isTrue);
  });
}
