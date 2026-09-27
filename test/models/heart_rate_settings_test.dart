import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/models/heart_rate_settings.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('defaults include VRChat heart beat parameter paths', () {
    final settings = HeartRateSettings.defaults();

    expect(settings.oscHeartbeatIntPath, '/avatar/parameters/HeartBeatInt');
    expect(settings.oscHeartbeatPulsePath, '/avatar/parameters/HeartBeatPulse');
    expect(
      settings.oscHeartbeatTogglePath,
      '/avatar/parameters/HeartBeatToggle',
    );
    expect(settings.oscHeartbeatIntEnabled, isTrue);
    expect(settings.oscHeartbeatPulseEnabled, isTrue);
    expect(settings.oscHeartbeatToggleEnabled, isTrue);
    expect(settings.oscHeartbeatPulseDurationMs, 120);
  });

  test('heart beat parameter paths persist through preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final settings = HeartRateSettings.defaults().copyWith(
      oscHeartbeatIntPath: '/avatar/parameters/HBIntCustom',
      oscHeartbeatPulsePath: '/avatar/parameters/HBPulseCustom',
      oscHeartbeatTogglePath: '/avatar/parameters/HBToggleCustom',
    );

    await settings.save(prefs);
    final restored = HeartRateSettings.fromPrefs(prefs);

    expect(restored.oscHeartbeatIntPath, '/avatar/parameters/HBIntCustom');
    expect(restored.oscHeartbeatPulsePath, '/avatar/parameters/HBPulseCustom');
    expect(
      restored.oscHeartbeatTogglePath,
      '/avatar/parameters/HBToggleCustom',
    );
  });

  test('heart beat settings persist through preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final settings = HeartRateSettings.defaults().copyWith(
      oscHeartbeatIntEnabled: false,
      oscHeartbeatPulseEnabled: false,
      oscHeartbeatToggleEnabled: false,
      oscHeartbeatPulseDurationMs: 360,
    );

    await settings.save(prefs);
    final restored = HeartRateSettings.fromPrefs(prefs);

    expect(restored.oscHeartbeatIntEnabled, isFalse);
    expect(restored.oscHeartbeatPulseEnabled, isFalse);
    expect(restored.oscHeartbeatToggleEnabled, isFalse);
    expect(restored.oscHeartbeatPulseDurationMs, 360);
  });

  test('min/max heart rate persist through preferences', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final settings = HeartRateSettings.defaults().copyWith(
      minHeartRate: 60,
      maxHeartRate: 190,
    );

    await settings.save(prefs);
    final restored = HeartRateSettings.fromPrefs(prefs);

    expect(restored.minHeartRate, 60);
    expect(restored.maxHeartRate, 190);
  });

  test('percentFor matches bpm / maxHeartRate with default min of 0', () {
    final settings = HeartRateSettings.defaults();

    expect(settings.minHeartRate, 0);
    expect(settings.percentFor(100), 0.5);
    expect(settings.percentFor(200), 1.0);
    expect(settings.percentFor(300), 1.0); // clamped above
    expect(settings.percentFor(0), 0.0);
    expect(settings.percentFor(null), isNull);
  });

  test('percentFor maps the min-max span onto 0..1', () {
    final settings = HeartRateSettings.defaults().copyWith(
      minHeartRate: 60,
      maxHeartRate: 200,
    );

    expect(settings.percentFor(60), 0.0);
    expect(settings.percentFor(130), closeTo(0.5, 1e-9));
    expect(settings.percentFor(200), 1.0);
    expect(settings.percentFor(50), 0.0); // clamped below
    expect(settings.percentFor(220), 1.0); // clamped above
    expect(settings.percentFor(null), isNull);
  });

  test('percentFor returns null for a non-positive span', () {
    final settings = HeartRateSettings.defaults().copyWith(
      minHeartRate: 200,
      maxHeartRate: 200,
    );

    expect(settings.percentFor(150), isNull);
  });
}
