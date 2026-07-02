import 'dart:convert';
import 'dart:io';

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
}

int _nextOscOffset(int stringEnd) {
  var offset = stringEnd + 1;
  while (offset % 4 != 0) {
    offset++;
  }
  return offset;
}
