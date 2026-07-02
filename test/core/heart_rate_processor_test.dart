import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/core/heart_rate_processor.dart';
import 'package:hr_push/models/heart_rate_settings.dart';
import 'package:hr_push/services/push_coordinator.dart';

void main() {
  test('visible heart rate follows the last published OSC snapshot', () async {
    final events = <HeartRateEvent>[];
    final processor =
        HeartRateProcessor(
          pushCoordinator: PushCoordinator(onLog: (_, {error}) {}),
          onLog: (_) {},
          onHeartRateUpdate: events.add,
          onHrOnlineChange: (_) {},
        )..updateSettings(
          HeartRateSettings.defaults().copyWith(updateIntervalMs: 1000),
        );

    processor.handleHeartRateData(Uint8List.fromList([0, 80]));
    expect(events.single.bpm, 80);
    expect(processor.heartRate, 80);

    processor.handleHeartRateData(Uint8List.fromList([0, 96]));

    expect(events.single.bpm, 80);
    expect(
      processor.heartRate,
      80,
      reason: 'UI should not show a newer raw BPM before OSC is published.',
    );
    expect(processor.rawHeartRate, 96);
  });
}
