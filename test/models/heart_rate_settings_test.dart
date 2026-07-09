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
}
