// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Heart Rate';

  @override
  String get currentHeartRate => 'Current HR';

  @override
  String get bpmUnit => 'BPM';

  @override
  String get deviceOnline => 'Device Online';

  @override
  String get waitingForConnection => 'Waiting...';

  @override
  String get noDeviceConnected => 'No Device';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get connecting => 'Connecting...';

  @override
  String get autoReconnecting => 'Reconnecting...';

  @override
  String get connectDevice => 'Connect Device';

  @override
  String get signal => 'Signal';

  @override
  String get nearbyDevices => 'NEARBY DEVICES';

  @override
  String get scan => 'Scan';

  @override
  String get searching => 'Searching for devices...';

  @override
  String get noDevicesFound => 'No devices found.';

  @override
  String get rssi => 'RSSI';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get back => 'Back';

  @override
  String get save => 'Save';

  @override
  String get sectionWebHttp => 'Web / HTTP';

  @override
  String get fieldEndpoint => 'Endpoint';

  @override
  String get fieldInterval => 'Interval (ms)';

  @override
  String get sectionVrchatOsc => 'VRChat OSC';

  @override
  String get fieldAddress => 'Address';

  @override
  String get fieldConnectedParam => 'Connected Param';

  @override
  String get fieldHrValueParam => 'HR Value Param';

  @override
  String get fieldHrPercentParam => 'HR Percent Param';

  @override
  String get fieldMaxHr => 'Max HR';

  @override
  String get sectionOscChatbox => 'OSC Chatbox';

  @override
  String get fieldEnabled => 'Enabled';

  @override
  String get fieldTemplate => 'Template';

  @override
  String get sectionMqtt => 'MQTT Client';

  @override
  String get fieldBroker => 'Broker';

  @override
  String get fieldPort => 'Port';

  @override
  String get fieldTopic => 'Topic';

  @override
  String get fieldUsername => 'Username';

  @override
  String get fieldPassword => 'Password';

  @override
  String get fieldClientId => 'Client ID';

  @override
  String get sectionDebugging => 'Debugging';

  @override
  String get fieldEnableLogs => 'Enable Logs';

  @override
  String get btnViewLogs => 'View Logs';

  @override
  String get logsTitle => 'Logs';

  @override
  String get btnClear => 'Clear';

  @override
  String get filterAll => 'All';

  @override
  String get filterInfo => 'Info';

  @override
  String get filterError => 'Error';

  @override
  String get unknownDevice => 'Unknown Device';

  @override
  String get signalStrong => 'Strong Signal';

  @override
  String get signalMedium => 'Medium Signal';

  @override
  String get signalWeak => 'Weak Signal';
}
