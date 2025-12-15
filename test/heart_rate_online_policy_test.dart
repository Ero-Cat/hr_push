import 'package:flutter_blue_plus_windows/flutter_blue_plus_windows.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/heart_rate_manager.dart';

void main() {
  group('HeartRateManager.computeHrOnline', () {
    test('returns false when user initiated disconnect', () {
      final now = DateTime(2025, 12, 15, 12);
      final isOnline = HeartRateManager.computeHrOnline(
        userInitiatedDisconnect: true,
        adapterState: BluetoothAdapterState.on,
        connectionState: BluetoothConnectionState.connected,
        now: now,
        lastHeartRateAt: now.subtract(const Duration(seconds: 1)),
        connectedAt: now.subtract(const Duration(seconds: 1)),
      );
      expect(isOnline, isFalse);
    });

    test('returns false when adapter is off', () {
      final now = DateTime(2025, 12, 15, 12);
      final isOnline = HeartRateManager.computeHrOnline(
        userInitiatedDisconnect: false,
        adapterState: BluetoothAdapterState.off,
        connectionState: BluetoothConnectionState.connected,
        now: now,
        lastHeartRateAt: now.subtract(const Duration(seconds: 1)),
        connectedAt: now.subtract(const Duration(seconds: 1)),
      );
      expect(isOnline, isFalse);
    });

    test('returns true when heart rate is fresh even if disconnected', () {
      final now = DateTime(2025, 12, 15, 12);
      final isOnline = HeartRateManager.computeHrOnline(
        userInitiatedDisconnect: false,
        adapterState: BluetoothAdapterState.on,
        connectionState: BluetoothConnectionState.disconnected,
        now: now,
        lastHeartRateAt: now.subtract(const Duration(seconds: 2)),
        connectedAt: null,
      );
      expect(isOnline, isTrue);
    });

    test('returns true right after connect before first sample', () {
      final now = DateTime(2025, 12, 15, 12);
      final isOnline = HeartRateManager.computeHrOnline(
        userInitiatedDisconnect: false,
        adapterState: BluetoothAdapterState.on,
        connectionState: BluetoothConnectionState.connected,
        now: now,
        lastHeartRateAt: null,
        connectedAt: now.subtract(const Duration(seconds: 1)),
      );
      expect(isOnline, isTrue);
    });

    test('returns false when no sample and connect grace expired', () {
      final now = DateTime(2025, 12, 15, 12);
      final isOnline = HeartRateManager.computeHrOnline(
        userInitiatedDisconnect: false,
        adapterState: BluetoothAdapterState.on,
        connectionState: BluetoothConnectionState.connected,
        now: now,
        lastHeartRateAt: null,
        connectedAt: now.subtract(const Duration(seconds: 10)),
        initialGrace: const Duration(seconds: 3),
      );
      expect(isOnline, isFalse);
    });

    test('returns false when heart rate is stale', () {
      final now = DateTime(2025, 12, 15, 12);
      final isOnline = HeartRateManager.computeHrOnline(
        userInitiatedDisconnect: false,
        adapterState: BluetoothAdapterState.on,
        connectionState: BluetoothConnectionState.disconnected,
        now: now,
        lastHeartRateAt: now.subtract(const Duration(seconds: 30)),
        connectedAt: null,
        hrFreshFor: const Duration(seconds: 6),
      );
      expect(isOnline, isFalse);
    });
  });
}
