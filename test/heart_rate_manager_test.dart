import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/heart_rate_manager.dart';

void main() {
  // Constructing HeartRateManager wires UniversalBle's callback channels,
  // which need an initialized test binding even in plain unit tests.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('reconnectDelayFor', () {
    test('immediate attempts skip the backoff', () {
      expect(
        HeartRateManager.reconnectDelayFor(1, immediate: true),
        Duration.zero,
      );
    });

    test('backs off 3/6/9s then 10s then 30s', () {
      expect(
        HeartRateManager.reconnectDelayFor(1, immediate: false),
        const Duration(seconds: 3),
      );
      expect(
        HeartRateManager.reconnectDelayFor(2, immediate: false),
        const Duration(seconds: 6),
      );
      expect(
        HeartRateManager.reconnectDelayFor(3, immediate: false),
        const Duration(seconds: 9),
      );
      expect(
        HeartRateManager.reconnectDelayFor(4, immediate: false),
        const Duration(seconds: 10),
      );
      expect(
        HeartRateManager.reconnectDelayFor(6, immediate: false),
        const Duration(seconds: 30),
      );
    });

    test('gives up once attempts reach the cap', () {
      expect(HeartRateManager.reconnectDelayFor(10, immediate: false), isNull);
      expect(HeartRateManager.reconnectDelayFor(11, immediate: false), isNull);
      // One below the cap still schedules.
      expect(
        HeartRateManager.reconnectDelayFor(9, immediate: false),
        isNotNull,
      );
    });
  });

  group('shouldForceReconnect', () {
    final now = DateTime(2026, 1, 1, 12, 0, 0);

    test('never fires without any HR data AND no connection time', () {
      expect(
        HeartRateManager.shouldForceReconnect(
          now: now,
          lastHeartRateAt: null,
          connectedAt: null,
        ),
        isFalse,
      );
    });

    test('fires for zombie connections that never sent HR data', () {
      // Connected 21s ago, no heart rate ever received (Redmi watch without
      // heart-rate broadcast): must be detected, not silently ignored.
      expect(
        HeartRateManager.shouldForceReconnect(
          now: now,
          lastHeartRateAt: null,
          connectedAt: now.subtract(const Duration(seconds: 21)),
        ),
        isTrue,
      );
      expect(
        HeartRateManager.shouldForceReconnect(
          now: now,
          lastHeartRateAt: null,
          connectedAt: now.subtract(const Duration(seconds: 10)),
        ),
        isFalse,
      );
    });

    test('fires after 2x stale threshold without fresh HR data', () {
      expect(
        HeartRateManager.shouldForceReconnect(
          now: now,
          lastHeartRateAt: now.subtract(const Duration(seconds: 13)),
          connectedAt: now.subtract(const Duration(minutes: 5)),
        ),
        isTrue,
      );
      expect(
        HeartRateManager.shouldForceReconnect(
          now: now,
          lastHeartRateAt: now.subtract(const Duration(seconds: 11)),
          connectedAt: now.subtract(const Duration(minutes: 5)),
        ),
        isFalse,
      );
    });
  });

  group('setUiVisible', () {
    test('hiding is silent, showing refreshes the UI', () {
      final manager = HeartRateManager();
      addTearDown(manager.dispose);

      var notifications = 0;
      manager.addListener(() => notifications++);

      manager.setUiVisible(false);
      expect(manager.uiVisible, isFalse);
      expect(notifications, 0, reason: 'hiding must not wake listeners');

      // Repeated values are idempotent.
      manager.setUiVisible(false);
      expect(notifications, 0);

      manager.setUiVisible(true);
      expect(manager.uiVisible, isTrue);
      // At least the refresh notification fires (resuming a useful scan
      // may notify again, which is legitimate UI state).
      expect(notifications, greaterThanOrEqualTo(1));

      final afterShow = notifications;
      manager.setUiVisible(true);
      expect(notifications, afterShow, reason: 'repeated shows are silent');
    });
  });
}
