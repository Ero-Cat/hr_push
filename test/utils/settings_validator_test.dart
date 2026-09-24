import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/utils/settings_validator.dart';

void main() {
  group('pushEndpoint', () {
    test('accepts empty (disabled) and valid http/https/ws/wss', () {
      expect(SettingsValidator.pushEndpoint(''), isNull);
      expect(SettingsValidator.pushEndpoint('  '), isNull);
      expect(
        SettingsValidator.pushEndpoint('https://example.com/hook'),
        isNull,
      );
      expect(SettingsValidator.pushEndpoint('wss://example.com/hr'), isNull);
      expect(SettingsValidator.pushEndpoint('http://192.168.1.5:8080'), isNull);
    });

    test('rejects garbage and unsupported schemes', () {
      expect(SettingsValidator.pushEndpoint('not-a-url'), 'errInvalidUrl');
      expect(
        SettingsValidator.pushEndpoint('ftp://example.com'),
        'errInvalidUrl',
      );
      expect(
        SettingsValidator.pushEndpoint('example.com/hook'),
        'errInvalidUrl',
      );
    });
  });

  group('oscAddress', () {
    test('accepts empty, host:port and IPv4', () {
      expect(SettingsValidator.oscAddress(''), isNull);
      expect(SettingsValidator.oscAddress('127.0.0.1:9000'), isNull);
      expect(SettingsValidator.oscAddress('localhost:9000'), isNull);
    });

    test('rejects missing port or malformed host', () {
      expect(SettingsValidator.oscAddress('127.0.0.1'), 'errInvalidOscAddress');
      expect(SettingsValidator.oscAddress(':9000'), 'errInvalidOscAddress');
      expect(SettingsValidator.oscAddress('host:0'), 'errInvalidOscAddress');
    });
  });

  group('numeric fields', () {
    test('port', () {
      expect(SettingsValidator.port(''), isNull);
      expect(SettingsValidator.port('1883'), isNull);
      expect(SettingsValidator.port('8883'), isNull);
      expect(SettingsValidator.port('0'), 'errInvalidPort');
      expect(SettingsValidator.port('70000'), 'errInvalidPort');
      expect(SettingsValidator.port('abc'), 'errInvalidPort');
      expect(SettingsValidator.parsePort('1883', 1234), 1883);
      expect(SettingsValidator.parsePort('', 1234), 1234);
    });

    test('updateIntervalMs', () {
      expect(SettingsValidator.updateIntervalMs('1000'), isNull);
      expect(SettingsValidator.updateIntervalMs('249'), 'errInvalidInterval');
      expect(SettingsValidator.updateIntervalMs('250'), isNull);
      expect(SettingsValidator.updateIntervalMs('61000'), 'errInvalidInterval');
      expect(SettingsValidator.updateIntervalMs('abc'), 'errInvalidInterval');
    });

    test('maxHeartRate', () {
      expect(SettingsValidator.maxHeartRate('200'), isNull);
      expect(SettingsValidator.maxHeartRate('99'), 'errInvalidMaxHr');
      expect(SettingsValidator.maxHeartRate('251'), 'errInvalidMaxHr');
    });

    test('heartbeatPulseDurationMs', () {
      expect(SettingsValidator.heartbeatPulseDurationMs('120'), isNull);
      expect(
        SettingsValidator.heartbeatPulseDurationMs('10'),
        'errInvalidPulseDuration',
      );
      expect(
        SettingsValidator.heartbeatPulseDurationMs('2000'),
        'errInvalidPulseDuration',
      );
    });
  });

  group('oscPath', () {
    test('accepts empty and slash-prefixed paths', () {
      expect(SettingsValidator.oscPath(''), isNull);
      expect(SettingsValidator.oscPath('/avatar/parameters/hr_val'), isNull);
      expect(
        SettingsValidator.oscPath('avatar/parameters'),
        'errInvalidOscPath',
      );
    });
  });
}
