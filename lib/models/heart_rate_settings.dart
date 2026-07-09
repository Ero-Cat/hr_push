import 'package:shared_preferences/shared_preferences.dart';

/// Heart rate settings configuration model
class HeartRateSettings {
  const HeartRateSettings({
    required this.pushEndpoint,
    required this.oscAddress,
    required this.oscHrConnectedPath,
    required this.oscHrValuePath,
    required this.oscHrPercentPath,
    required this.oscHeartbeatIntPath,
    required this.oscHeartbeatPulsePath,
    required this.oscHeartbeatTogglePath,
    required this.oscChatboxEnabled,
    required this.oscChatboxTemplate,
    required this.maxHeartRate,
    required this.updateIntervalMs,
    required this.logEnabled,
    required this.mqttBroker,
    required this.mqttPort,
    required this.mqttTopic,
    required this.mqttUsername,
    required this.mqttPassword,
    required this.mqttClientId,
  });

  final String pushEndpoint;
  final String oscAddress;
  final String oscHrConnectedPath;
  final String oscHrValuePath;
  final String oscHrPercentPath;
  final String oscHeartbeatIntPath;
  final String oscHeartbeatPulsePath;
  final String oscHeartbeatTogglePath;
  final bool oscChatboxEnabled;
  final String oscChatboxTemplate;
  final int maxHeartRate;
  final int updateIntervalMs;
  final bool logEnabled;
  final String mqttBroker;
  final int mqttPort;
  final String mqttTopic;
  final String mqttUsername;
  final String mqttPassword;
  final String mqttClientId;

  // Default values
  static const _defaultPushEndpoint = '';
  static const _defaultOscAddress = '';
  static const _defaultHrConnectedPath = '/avatar/parameters/hr_connected';
  static const _defaultHrValuePath = '/avatar/parameters/hr_val';
  static const _defaultHrPercentPath = '/avatar/parameters/hr_percent';
  static const _defaultHeartbeatIntPath = '/avatar/parameters/HeartBeatInt';
  static const _defaultHeartbeatPulsePath = '/avatar/parameters/HeartBeatPulse';
  static const _defaultHeartbeatTogglePath =
      '/avatar/parameters/HeartBeatToggle';
  static const _defaultOscChatboxEnabled = false;
  static const _defaultOscChatboxTemplate = '💓{hr}';
  static const _defaultMaxHeartRate = 200;
  static const _defaultUpdateIntervalMs = 1000;
  static const _defaultLogEnabled = false;
  static const _defaultMqttBroker = '';
  static const _defaultMqttPort = 1883;
  static const _defaultMqttTopic = 'hr_push';
  static const _defaultMqttUsername = '';
  static const _defaultMqttPassword = '';
  static const _defaultMqttClientId = '';

  // SharedPreferences keys
  static const _kPushEndpointKey = 'cfg_push_endpoint';
  static const _kOscAddressKey = 'cfg_osc_address';
  static const _kOscConnectedKey = 'cfg_osc_connected_path';
  static const _kOscValueKey = 'cfg_osc_value_path';
  static const _kOscPercentKey = 'cfg_osc_percent_path';
  static const _kOscHeartbeatIntKey = 'cfg_osc_heartbeat_int_path';
  static const _kOscHeartbeatPulseKey = 'cfg_osc_heartbeat_pulse_path';
  static const _kOscHeartbeatToggleKey = 'cfg_osc_heartbeat_toggle_path';
  static const _kOscChatboxEnabledKey = 'cfg_osc_chatbox_enabled';
  static const _kOscChatboxTemplateKey = 'cfg_osc_chatbox_template';
  static const _kMaxHeartRateKey = 'cfg_max_heart_rate';
  static const _kUpdateIntervalKey = 'cfg_update_interval_ms';
  static const _kLogEnabledKey = 'cfg_log_enabled';
  static const _kMqttBrokerKey = 'cfg_mqtt_broker';
  static const _kMqttPortKey = 'cfg_mqtt_port';
  static const _kMqttTopicKey = 'cfg_mqtt_topic';
  static const _kMqttUsernameKey = 'cfg_mqtt_username';
  static const _kMqttPasswordKey = 'cfg_mqtt_password';
  static const _kMqttClientIdKey = 'cfg_mqtt_client_id';

  factory HeartRateSettings.defaults() {
    return const HeartRateSettings(
      pushEndpoint: _defaultPushEndpoint,
      oscAddress: _defaultOscAddress,
      oscHrConnectedPath: _defaultHrConnectedPath,
      oscHrValuePath: _defaultHrValuePath,
      oscHrPercentPath: _defaultHrPercentPath,
      oscHeartbeatIntPath: _defaultHeartbeatIntPath,
      oscHeartbeatPulsePath: _defaultHeartbeatPulsePath,
      oscHeartbeatTogglePath: _defaultHeartbeatTogglePath,
      oscChatboxEnabled: _defaultOscChatboxEnabled,
      oscChatboxTemplate: _defaultOscChatboxTemplate,
      maxHeartRate: _defaultMaxHeartRate,
      updateIntervalMs: _defaultUpdateIntervalMs,
      logEnabled: _defaultLogEnabled,
      mqttBroker: _defaultMqttBroker,
      mqttPort: _defaultMqttPort,
      mqttTopic: _defaultMqttTopic,
      mqttUsername: _defaultMqttUsername,
      mqttPassword: _defaultMqttPassword,
      mqttClientId: _defaultMqttClientId,
    );
  }

  factory HeartRateSettings.fromPrefs(SharedPreferences? prefs) {
    if (prefs == null) return HeartRateSettings.defaults();

    return HeartRateSettings(
      pushEndpoint: prefs.getString(_kPushEndpointKey) ?? _defaultPushEndpoint,
      oscAddress: prefs.getString(_kOscAddressKey) ?? _defaultOscAddress,
      oscHrConnectedPath:
          prefs.getString(_kOscConnectedKey) ?? _defaultHrConnectedPath,
      oscHrValuePath: prefs.getString(_kOscValueKey) ?? _defaultHrValuePath,
      oscHrPercentPath:
          prefs.getString(_kOscPercentKey) ?? _defaultHrPercentPath,
      oscHeartbeatIntPath:
          prefs.getString(_kOscHeartbeatIntKey) ?? _defaultHeartbeatIntPath,
      oscHeartbeatPulsePath:
          prefs.getString(_kOscHeartbeatPulseKey) ?? _defaultHeartbeatPulsePath,
      oscHeartbeatTogglePath:
          prefs.getString(_kOscHeartbeatToggleKey) ??
          _defaultHeartbeatTogglePath,
      oscChatboxEnabled:
          prefs.getBool(_kOscChatboxEnabledKey) ?? _defaultOscChatboxEnabled,
      oscChatboxTemplate:
          prefs.getString(_kOscChatboxTemplateKey) ??
          _defaultOscChatboxTemplate,
      maxHeartRate: prefs.getInt(_kMaxHeartRateKey) ?? _defaultMaxHeartRate,
      updateIntervalMs:
          prefs.getInt(_kUpdateIntervalKey) ?? _defaultUpdateIntervalMs,
      logEnabled: prefs.getBool(_kLogEnabledKey) ?? _defaultLogEnabled,
      mqttBroker: prefs.getString(_kMqttBrokerKey) ?? _defaultMqttBroker,
      mqttPort: prefs.getInt(_kMqttPortKey) ?? _defaultMqttPort,
      mqttTopic: prefs.getString(_kMqttTopicKey) ?? _defaultMqttTopic,
      mqttUsername: prefs.getString(_kMqttUsernameKey) ?? _defaultMqttUsername,
      mqttPassword: prefs.getString(_kMqttPasswordKey) ?? _defaultMqttPassword,
      mqttClientId: prefs.getString(_kMqttClientIdKey) ?? _defaultMqttClientId,
    );
  }

  Future<void> save(SharedPreferences? prefs) async {
    if (prefs == null) return;
    await prefs.setString(_kPushEndpointKey, pushEndpoint);
    await prefs.setString(_kOscAddressKey, oscAddress);
    await prefs.setString(_kOscConnectedKey, oscHrConnectedPath);
    await prefs.setString(_kOscValueKey, oscHrValuePath);
    await prefs.setString(_kOscPercentKey, oscHrPercentPath);
    await prefs.setString(_kOscHeartbeatIntKey, oscHeartbeatIntPath);
    await prefs.setString(_kOscHeartbeatPulseKey, oscHeartbeatPulsePath);
    await prefs.setString(_kOscHeartbeatToggleKey, oscHeartbeatTogglePath);
    await prefs.setBool(_kOscChatboxEnabledKey, oscChatboxEnabled);
    await prefs.setString(_kOscChatboxTemplateKey, oscChatboxTemplate);
    await prefs.setInt(_kMaxHeartRateKey, maxHeartRate);
    await prefs.setInt(_kUpdateIntervalKey, updateIntervalMs);
    await prefs.setBool(_kLogEnabledKey, logEnabled);
    await prefs.setString(_kMqttBrokerKey, mqttBroker);
    await prefs.setInt(_kMqttPortKey, mqttPort);
    await prefs.setString(_kMqttTopicKey, mqttTopic);
    await prefs.setString(_kMqttUsernameKey, mqttUsername);
    await prefs.setString(_kMqttPasswordKey, mqttPassword);
    await prefs.setString(_kMqttClientIdKey, mqttClientId);
  }

  HeartRateSettings copyWith({
    String? pushEndpoint,
    String? oscAddress,
    String? oscHrConnectedPath,
    String? oscHrValuePath,
    String? oscHrPercentPath,
    String? oscHeartbeatIntPath,
    String? oscHeartbeatPulsePath,
    String? oscHeartbeatTogglePath,
    bool? oscChatboxEnabled,
    String? oscChatboxTemplate,
    int? maxHeartRate,
    int? updateIntervalMs,
    bool? logEnabled,
    String? mqttBroker,
    int? mqttPort,
    String? mqttTopic,
    String? mqttUsername,
    String? mqttPassword,
    String? mqttClientId,
  }) {
    return HeartRateSettings(
      pushEndpoint: pushEndpoint ?? this.pushEndpoint,
      oscAddress: oscAddress ?? this.oscAddress,
      oscHrConnectedPath: oscHrConnectedPath ?? this.oscHrConnectedPath,
      oscHrValuePath: oscHrValuePath ?? this.oscHrValuePath,
      oscHrPercentPath: oscHrPercentPath ?? this.oscHrPercentPath,
      oscHeartbeatIntPath: oscHeartbeatIntPath ?? this.oscHeartbeatIntPath,
      oscHeartbeatPulsePath:
          oscHeartbeatPulsePath ?? this.oscHeartbeatPulsePath,
      oscHeartbeatTogglePath:
          oscHeartbeatTogglePath ?? this.oscHeartbeatTogglePath,
      oscChatboxEnabled: oscChatboxEnabled ?? this.oscChatboxEnabled,
      oscChatboxTemplate: oscChatboxTemplate ?? this.oscChatboxTemplate,
      maxHeartRate: maxHeartRate ?? this.maxHeartRate,
      updateIntervalMs: updateIntervalMs ?? this.updateIntervalMs,
      logEnabled: logEnabled ?? this.logEnabled,
      mqttBroker: mqttBroker ?? this.mqttBroker,
      mqttPort: mqttPort ?? this.mqttPort,
      mqttTopic: mqttTopic ?? this.mqttTopic,
      mqttUsername: mqttUsername ?? this.mqttUsername,
      mqttPassword: mqttPassword ?? this.mqttPassword,
      mqttClientId: mqttClientId ?? this.mqttClientId,
    );
  }
}
