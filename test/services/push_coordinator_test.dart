import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/models/heart_rate_settings.dart';
import 'package:hr_push/services/push_coordinator.dart';

void main() {
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
    expect(await _nextOscAddress(packets), '/avatar/parameters/hr_old');

    coordinator.updateSettings(
      initial.copyWith(oscHrValuePath: '/avatar/parameters/hr_new'),
    );
    await coordinator.sendHeartRate(
      bpm: 81,
      percent: null,
      timestamp: DateTime(2026),
    );

    expect(await _nextOscAddress(packets), '/avatar/parameters/hr_new');
  });
}

Future<String> _nextOscAddress(Stream<Datagram> packets) async {
  final datagram = await packets.first.timeout(const Duration(seconds: 2));
  return _readOscString(datagram.data, 0);
}

String _readOscString(Uint8List packet, int offset) {
  final end = packet.indexOf(0, offset);
  return String.fromCharCodes(packet.sublist(offset, end));
}
