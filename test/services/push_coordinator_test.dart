import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/models/heart_rate_settings.dart';
import 'package:hr_push/services/push_coordinator.dart';

void main() {
  test('OSC status reports sent without requiring a server response', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);

    final coordinator = PushCoordinator(
      onLog: (_, {error}) {},
      oscAcknowledgementTimeout: const Duration(milliseconds: 50),
    );
    addTearDown(coordinator.dispose);

    coordinator.updateSettings(
      HeartRateSettings.defaults().copyWith(
        oscAddress: '127.0.0.1:${socket.port}',
      ),
    );
    expect(coordinator.oscStatus.state, OscSendState.ready);

    await coordinator.sendHeartRate(
      bpm: 80,
      percent: null,
      timestamp: DateTime(2026),
    );

    expect(coordinator.oscStatus.state, OscSendState.sent);
    expect(coordinator.oscStatus.target, '127.0.0.1:${socket.port}');
    expect(coordinator.oscStatus.updatedAt, isNotNull);
  });

  test(
    'OSC status reports acknowledged after receiving optional pong',
    () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(socket.close);
      final sub = socket.listen((event) {
        if (event != RawSocketEvent.read) return;
        final datagram = socket.receive();
        if (datagram == null) return;
        if (_readOscString(datagram.data, 0) == '/hr_push/ping') {
          socket.send(
            _oscMessage('/hr_push/pong'),
            datagram.address,
            datagram.port,
          );
        }
      });
      addTearDown(sub.cancel);

      final coordinator = PushCoordinator(
        onLog: (_, {error}) {},
        oscAcknowledgementTimeout: const Duration(seconds: 1),
      );
      addTearDown(coordinator.dispose);

      coordinator.updateSettings(
        HeartRateSettings.defaults().copyWith(
          oscAddress: '127.0.0.1:${socket.port}',
        ),
      );

      await coordinator.sendHeartRate(
        bpm: 80,
        percent: null,
        timestamp: DateTime(2026),
      );

      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(coordinator.oscStatus.state, OscSendState.acknowledged);
    },
  );

  test('OSC status reports error when the target is invalid', () async {
    final coordinator = PushCoordinator(onLog: (_, {error}) {});
    addTearDown(coordinator.dispose);

    coordinator.updateSettings(
      HeartRateSettings.defaults().copyWith(oscAddress: '127.0.0.1:notaport'),
    );

    await coordinator.sendHeartRate(
      bpm: 80,
      percent: null,
      timestamp: DateTime(2026),
    );

    expect(coordinator.oscStatus.state, OscSendState.error);
    expect(coordinator.oscStatus.message, isNotEmpty);
  });

  test('OSC path changes take effect without restarting the app', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    final packets = socket
        .where((event) => event == RawSocketEvent.read)
        .map((_) => socket.receive())
        .where((packet) => packet != null)
        .cast<Datagram>()
        .asBroadcastStream();

    final coordinator = PushCoordinator(onLog: (_, {error}) {});
    addTearDown(coordinator.dispose);

    final initial = HeartRateSettings.defaults().copyWith(
      oscAddress: '127.0.0.1:${socket.port}',
      oscHrValuePath: '/avatar/parameters/hr_old',
    );
    coordinator.updateSettings(initial);
    await coordinator.sendHeartRate(
      bpm: 80,
      percent: null,
      timestamp: DateTime(2026),
    );
    expect(
      await _nextOscAddress(packets, prefix: '/avatar/parameters/'),
      '/avatar/parameters/hr_old',
    );

    coordinator.updateSettings(
      initial.copyWith(oscHrValuePath: '/avatar/parameters/hr_new'),
    );
    await coordinator.sendHeartRate(
      bpm: 81,
      percent: null,
      timestamp: DateTime(2026),
    );

    expect(
      await _nextOscAddress(packets, prefix: '/avatar/parameters/'),
      '/avatar/parameters/hr_new',
    );
  });

  test(
    'OSC heartbeat path changes take effect without restarting the app',
    () async {
      final socket = await RawDatagramSocket.bind(
        InternetAddress.loopbackIPv4,
        0,
      );
      addTearDown(socket.close);
      final packets = socket
          .where((event) => event == RawSocketEvent.read)
          .map((_) => socket.receive())
          .where((packet) => packet != null)
          .cast<Datagram>()
          .asBroadcastStream();

      final coordinator = PushCoordinator(onLog: (_, {error}) {});
      addTearDown(coordinator.dispose);

      final initial = HeartRateSettings.defaults().copyWith(
        oscAddress: '127.0.0.1:${socket.port}',
        oscHeartbeatIntPath: '/avatar/parameters/HeartBeatIntOld',
      );
      coordinator.updateSettings(initial);
      await coordinator.sendHeartRate(
        bpm: 240,
        percent: null,
        timestamp: DateTime(2026),
      );
      expect(
        await _nextOscAddress(
          packets,
          exact: '/avatar/parameters/HeartBeatIntOld',
        ),
        '/avatar/parameters/HeartBeatIntOld',
      );

      coordinator.updateSettings(
        initial.copyWith(
          oscHeartbeatIntPath: '/avatar/parameters/HeartBeatIntNew',
        ),
      );
      await coordinator.sendHeartRate(
        bpm: 240,
        percent: null,
        timestamp: DateTime(2026),
      );

      expect(
        await _nextOscAddress(
          packets,
          exact: '/avatar/parameters/HeartBeatIntNew',
        ),
        '/avatar/parameters/HeartBeatIntNew',
      );
    },
  );

  test('disconnecting stops OSC heartbeat loop', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    final packets = socket
        .where((event) => event == RawSocketEvent.read)
        .map((_) => socket.receive())
        .where((packet) => packet != null)
        .cast<Datagram>()
        .asBroadcastStream();

    final coordinator = PushCoordinator(onLog: (_, {error}) {});
    addTearDown(coordinator.dispose);

    coordinator.updateSettings(
      HeartRateSettings.defaults().copyWith(
        oscAddress: '127.0.0.1:${socket.port}',
      ),
    );
    await coordinator.sendHeartRate(
      bpm: 240,
      percent: null,
      timestamp: DateTime(2026),
    );
    await _nextOscAddress(packets, exact: '/avatar/parameters/HeartBeatToggle');

    await coordinator.sendConnectionStatus(false, force: true);

    await expectLater(
      _nextOscAddress(
        packets,
        prefix: '/avatar/parameters/HeartBeatToggle',
        timeout: const Duration(milliseconds: 450),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}

Future<String> _nextOscAddress(
  Stream<Datagram> packets, {
  String? exact,
  String? prefix,
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final datagram = await packets.first.timeout(
      deadline.difference(DateTime.now()),
    );
    final address = _readOscString(datagram.data, 0);
    if (exact != null && address == exact) {
      return address;
    }
    if (exact == null && (prefix == null || address.startsWith(prefix))) {
      return address;
    }
  }
  throw TimeoutException('OSC address not received');
}

String _readOscString(Uint8List packet, int offset) {
  final end = packet.indexOf(0, offset);
  return String.fromCharCodes(packet.sublist(offset, end));
}

Uint8List _oscMessage(String address) {
  final data = <int>[];
  data.addAll(_oscString(address));
  data.addAll(_oscString(','));
  return Uint8List.fromList(data);
}

List<int> _oscString(String value) {
  final padded = <int>[...value.codeUnits, 0];
  while (padded.length % 4 != 0) {
    padded.add(0);
  }
  return padded;
}
