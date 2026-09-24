import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/ble/ble_adapter.dart';
import 'package:hr_push/ble/ble_scanner.dart';
import 'package:hr_push/models/nearby_device.dart';

BleDeviceInfo _device({
  String id = 'aa:bb:cc:dd:ee:ff',
  String name = '',
  int rssi = -55,
  List<String> serviceUuids = const [],
}) {
  return BleDeviceInfo(
    id: id,
    name: name,
    rssi: rssi,
    serviceUuids: serviceUuids,
  );
}

void main() {
  group('isWearableHeartRateCandidate', () {
    test('accepts Redmi watches by name', () {
      expect(
        BleScanner.isWearableHeartRateCandidate(_device(name: 'Redmi Watch')),
        isTrue,
      );
      expect(
        BleScanner.isWearableHeartRateCandidate(
          _device(name: 'Redmi Smart Band 3'),
        ),
        isTrue,
      );
    });

    test('accepts unnamed devices that advertise the HR service', () {
      expect(
        BleScanner.isWearableHeartRateCandidate(
          _device(serviceUuids: ['0000180d-0000-1000-8000-00805f9b34fb']),
        ),
        isTrue,
      );
    });

    test('drops unnamed devices without the HR service', () {
      expect(BleScanner.isWearableHeartRateCandidate(_device()), isFalse);
    });

    test('drops phones and PCs', () {
      expect(
        BleScanner.isWearableHeartRateCandidate(_device(name: 'iPhone 15')),
        isFalse,
      );
      expect(
        BleScanner.isWearableHeartRateCandidate(_device(name: 'MacBook Pro')),
        isFalse,
      );
    });

    test('wearable keywords win over phone keywords', () {
      expect(
        BleScanner.isWearableHeartRateCandidate(
          _device(name: 'Galaxy Watch 6'),
        ),
        isTrue,
      );
    });
  });

  group('isXiaomiDevice', () {
    test('matches Xiaomi and Redmi names', () {
      expect(BleScanner.isXiaomiDevice('Xiaomi Smart Band 9'), isTrue);
      expect(BleScanner.isXiaomiDevice('Redmi Watch 5'), isTrue);
      expect(BleScanner.isXiaomiDevice('小米手环9'), isTrue);
      expect(BleScanner.isXiaomiDevice('Polar H10'), isFalse);
    });
  });

  group('handleScanResult', () {
    test(
      'keeps unnamed HR devices with an empty localized-later name',
      () async {
        final found = <NearbyDevice>[];
        final scanner = BleScanner(
          onLog: (_, {error}) {},
          onDeviceFound: (device, isNew) => found.add(device),
          onBroadcastHeartRate: (bpm, rssi, name) {},
        );

        scanner.handleScanResult(
          _device(
            id: 'c1:c2:c3:c4:c5:c6',
            serviceUuids: ['0000180d-0000-1000-8000-00805f9b34fb'],
          ),
        );

        expect(scanner.nearbyDevices, hasLength(1));
        expect(scanner.nearbyDevices.first.name, isEmpty);
        expect(found, hasLength(1));
      },
    );

    test('prunes devices after the TTL', () async {
      final scanner = BleScanner(
        onLog: (_, {error}) {},
        onDeviceFound: (_, __) {},
        onBroadcastHeartRate: (bpm, rssi, name) {},
      );
      scanner.handleScanResult(
        _device(id: 'd1', name: 'Redmi Watch', rssi: -50),
      );
      expect(scanner.nearbyDevices, hasLength(1));

      // Simulate a device not seen again: rewind lastSeen beyond the TTL
      // (pruneNearby compares against DateTime.now()).
      final device = scanner.nearbyDevices.first;
      device.lastSeen = DateTime.now().subtract(
        BleScanner.nearbyTtl + const Duration(seconds: 1),
      );
      scanner.pruneNearby();

      expect(scanner.nearbyDevices, isEmpty);
    });
  });

  group('parseHeartRateValue', () {
    test('parses uint8 and uint16 measurements', () {
      expect(
        BleScanner.parseHeartRateValue(Uint8List.fromList([0x00, 72])),
        72,
      );
      expect(
        BleScanner.parseHeartRateValue(Uint8List.fromList([0x01, 0x48, 0x01])),
        0x0148,
      );
      expect(BleScanner.parseHeartRateValue(Uint8List.fromList([])), isNull);
    });
  });
}
