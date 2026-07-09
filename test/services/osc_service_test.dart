import 'dart:convert';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/services/osc_service.dart';

void main() {
  test('chatbox string arguments are encoded as UTF-8 OSC strings', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);

    final service = OscService(
      oscAddress: '127.0.0.1:${socket.port}',
      hrConnectedPath: '/avatar/parameters/hr_connected',
      hrValuePath: '/avatar/parameters/hr_val',
      hrPercentPath: '/avatar/parameters/hr_percent',
      heartbeatIntPath: '/avatar/parameters/HeartBeatInt',
      heartbeatPulsePath: '/avatar/parameters/HeartBeatPulse',
      heartbeatTogglePath: '/avatar/parameters/HeartBeatToggle',
      chatboxEnabled: true,
      chatboxTemplate: '心率{hr}💓',
    );
    addTearDown(service.dispose);

    await service.sendChatbox(88, 0.44);

    final datagram = await socket
        .where((event) => event == RawSocketEvent.read)
        .map((_) => socket.receive())
        .where((packet) => packet != null)
        .cast<Datagram>()
        .first
        .timeout(const Duration(seconds: 2));

    final packet = datagram.data;
    final addressEnd = packet.indexOf(0);
    final typeStart = _nextOscOffset(addressEnd);
    final typeEnd = packet.indexOf(0, typeStart);
    final firstArgStart = _nextOscOffset(typeEnd);
    final firstArgEnd = packet.indexOf(0, firstArgStart);
    final textBytes = packet.sublist(firstArgStart, firstArgEnd);

    expect(utf8.decode(textBytes), '心率88💓');
  });

  test('heart beat parameters pulse during QRS interval', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    final packets = _oscPackets(socket);

    final service = OscService(
      oscAddress: '127.0.0.1:${socket.port}',
      hrConnectedPath: '/avatar/parameters/hr_connected',
      hrValuePath: '/avatar/parameters/hr_val',
      hrPercentPath: '/avatar/parameters/hr_percent',
      heartbeatIntPath: '/avatar/parameters/HeartBeatInt',
      heartbeatPulsePath: '/avatar/parameters/HeartBeatPulse',
      heartbeatTogglePath: '/avatar/parameters/HeartBeatToggle',
      chatboxEnabled: false,
      chatboxTemplate: '',
    );
    addTearDown(service.dispose);

    await service.sendHeartRate(240, null);

    final activeInt = await _nextOscPacket(
      packets,
      '/avatar/parameters/HeartBeatInt',
    );
    final activePulse = await _nextOscPacket(
      packets,
      '/avatar/parameters/HeartBeatPulse',
    );
    final inactiveInt = await _nextOscPacket(
      packets,
      '/avatar/parameters/HeartBeatInt',
    );
    final inactivePulse = await _nextOscPacket(
      packets,
      '/avatar/parameters/HeartBeatPulse',
    );

    expect(activeInt.intValue, 1);
    expect(activePulse.boolValue, isTrue);
    expect(inactiveInt.intValue, 0);
    expect(inactivePulse.boolValue, isFalse);
  });

  test('heart beat toggle reverses with each heartbeat', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    final packets = _oscPackets(socket);

    final service = OscService(
      oscAddress: '127.0.0.1:${socket.port}',
      hrConnectedPath: '/avatar/parameters/hr_connected',
      hrValuePath: '/avatar/parameters/hr_val',
      hrPercentPath: '/avatar/parameters/hr_percent',
      heartbeatIntPath: '/avatar/parameters/HeartBeatInt',
      heartbeatPulsePath: '/avatar/parameters/HeartBeatPulse',
      heartbeatTogglePath: '/avatar/parameters/HeartBeatToggle',
      chatboxEnabled: false,
      chatboxTemplate: '',
    );
    addTearDown(service.dispose);

    await service.sendHeartRate(240, null);

    final firstToggle = await _nextOscPacket(
      packets,
      '/avatar/parameters/HeartBeatToggle',
    );
    final secondToggle = await _nextOscPacket(
      packets,
      '/avatar/parameters/HeartBeatToggle',
    );

    expect(firstToggle.boolValue, isFalse);
    expect(secondToggle.boolValue, isTrue);
  });

  test('disposing stops heart beat timer', () async {
    final socket = await RawDatagramSocket.bind(
      InternetAddress.loopbackIPv4,
      0,
    );
    addTearDown(socket.close);
    final packets = _oscPackets(socket);

    final service = OscService(
      oscAddress: '127.0.0.1:${socket.port}',
      hrConnectedPath: '/avatar/parameters/hr_connected',
      hrValuePath: '/avatar/parameters/hr_val',
      hrPercentPath: '/avatar/parameters/hr_percent',
      heartbeatIntPath: '/avatar/parameters/HeartBeatInt',
      heartbeatPulsePath: '/avatar/parameters/HeartBeatPulse',
      heartbeatTogglePath: '/avatar/parameters/HeartBeatToggle',
      chatboxEnabled: false,
      chatboxTemplate: '',
    );

    await service.sendHeartRate(240, null);
    await _nextOscPacket(packets, '/avatar/parameters/HeartBeatToggle');
    service.dispose();

    await expectLater(
      _nextOscPacket(
        packets,
        '/avatar/parameters/HeartBeatToggle',
        timeout: const Duration(milliseconds: 450),
      ),
      throwsA(isA<TimeoutException>()),
    );
  });
}

int _nextOscOffset(int stringEnd) {
  var offset = stringEnd + 1;
  while (offset % 4 != 0) {
    offset++;
  }
  return offset;
}

Stream<_OscPacket> _oscPackets(RawDatagramSocket socket) {
  return socket
      .where((event) => event == RawSocketEvent.read)
      .map((_) => socket.receive())
      .where((packet) => packet != null)
      .cast<Datagram>()
      .map((datagram) => _OscPacket.parse(datagram.data))
      .asBroadcastStream();
}

Future<_OscPacket> _nextOscPacket(
  Stream<_OscPacket> packets,
  String address, {
  Duration timeout = const Duration(seconds: 2),
}) async {
  final deadline = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(deadline)) {
    final packet = await packets.first.timeout(
      deadline.difference(DateTime.now()),
    );
    if (packet.address == address) return packet;
  }
  throw TimeoutException('OSC packet not received: $address');
}

class _OscPacket {
  const _OscPacket({
    required this.address,
    required this.typeTags,
    this.intValue,
  });

  final String address;
  final String typeTags;
  final int? intValue;

  bool? get boolValue {
    if (typeTags == ',T') return true;
    if (typeTags == ',F') return false;
    return null;
  }

  factory _OscPacket.parse(Uint8List packet) {
    final addressEnd = packet.indexOf(0);
    final typeStart = _nextOscOffset(addressEnd);
    final typeEnd = packet.indexOf(0, typeStart);
    final typeTags = utf8.decode(packet.sublist(typeStart, typeEnd));

    int? intValue;
    if (typeTags == ',i') {
      final valueStart = _nextOscOffset(typeEnd);
      intValue = ByteData.sublistView(
        packet,
        valueStart,
        valueStart + 4,
      ).getInt32(0, Endian.big);
    }

    return _OscPacket(
      address: utf8.decode(packet.sublist(0, addressEnd)),
      typeTags: typeTags,
      intValue: intValue,
    );
  }
}
