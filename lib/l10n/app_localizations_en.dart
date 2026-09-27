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
  String get fieldAddress => 'Receive address';

  @override
  String get fieldConnectedParam => 'Online status address';

  @override
  String get fieldHrValueParam => 'Live heart rate address';

  @override
  String get fieldHrPercentParam => 'Heart rate ratio address';

  @override
  String get fieldHeartbeatInt => 'Integer flash';

  @override
  String get fieldHeartbeatIntPath => 'Integer flash address';

  @override
  String get fieldHeartbeatPulse => 'Boolean flash';

  @override
  String get fieldHeartbeatPulsePath => 'Boolean flash address';

  @override
  String get fieldHeartbeatToggle => 'Beat toggle';

  @override
  String get fieldHeartbeatTogglePath => 'Beat toggle address';

  @override
  String get fieldHeartbeatDuration => 'Flash duration (ms)';

  @override
  String get fieldMinHr => 'Min HR (0%)';

  @override
  String get fieldMaxHr => 'Max HR (100%)';

  @override
  String get oscStatusTitle => 'OSC Push';

  @override
  String get oscStatusDisabled => 'Disabled';

  @override
  String get oscStatusReady => 'Ready';

  @override
  String get oscStatusSent => 'Sent';

  @override
  String get oscStatusAcknowledged => 'Acknowledged';

  @override
  String get oscStatusError => 'Send failed';

  @override
  String get sectionOscChatbox => 'OSC Chatbox';

  @override
  String get sectionBackgroundRuntime => 'Background runtime';

  @override
  String get btnBackgroundRuntime => 'Protect background runtime';

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

  @override
  String get waitingForBluetooth => 'Waiting for Bluetooth...';

  @override
  String get platformNotSupported => 'Bluetooth not supported on this platform';

  @override
  String get notificationPermissionDenied => 'Notification permission denied';

  @override
  String get pleaseEnableBluetooth => 'Please enable Bluetooth';

  @override
  String get bluetoothNotSupported => 'Bluetooth not supported';

  @override
  String get bluetoothUnavailable => 'Bluetooth unavailable';

  @override
  String get permissionDenied => 'Bluetooth/Location permission denied';

  @override
  String get staleConnectionReconnecting => 'Connection stale, reconnecting...';

  @override
  String get scanningDevices => 'Scanning for devices...';

  @override
  String get disconnected => 'Disconnected';

  @override
  String get scanNotSupported => 'Scanning not supported';

  @override
  String get unnamedDevice => 'Unnamed Device';

  @override
  String get connectNotSupported => 'Connection not supported';

  @override
  String connectingTo(String device) {
    return 'Connecting to $device...';
  }

  @override
  String get deviceConnected => 'Connected';

  @override
  String get xiaomiGuideTitle => 'Heart rate service not found';

  @override
  String get xiaomiGuideBody =>
      'Xiaomi/Redmi watches only expose the standard heart rate service after you enable Heart Rate Broadcast on the watch:\n\n1. On the watch, open Settings → Heart Rate and turn on \"Heart Rate Broadcast\" (or \"Share HR\")\n2. Make sure the watch is not connected to the Mi Fitness app\n3. Come back here and rescan, then connect';

  @override
  String get xiaomiGuideRescan => 'Rescan';

  @override
  String get xiaomiGuideGotIt => 'Got it';

  @override
  String get sectionGeneral => 'General';

  @override
  String get showAdvanced => 'Show advanced';

  @override
  String get hideAdvanced => 'Hide advanced';

  @override
  String get hintOscEmpty => 'Leave empty to disable OSC push';

  @override
  String get btnFillDefault => 'Use default';

  @override
  String get btnTest => 'Test';

  @override
  String get testSuccess => 'Test passed';

  @override
  String get testFailed => 'Failed';

  @override
  String get hintOscNote =>
      'OSC is connectionless; the test only verifies the datagram can be sent';

  @override
  String get errInvalidUrl => 'Enter a valid http/https/ws/wss URL';

  @override
  String get errInvalidOscAddress => 'Expected host:port (port 1-65535)';

  @override
  String get errInvalidOscPath => 'OSC path must start with /';

  @override
  String get errInvalidPort => 'Port must be between 1 and 65535';

  @override
  String get errInvalidInterval => 'Interval must be between 250 and 60000 ms';

  @override
  String get errInvalidMinHr => 'Min heart rate must be between 0 and 180';

  @override
  String get errInvalidMaxHr => 'Max heart rate must be between 100 and 250';

  @override
  String get errInvalidHrRange =>
      'Min heart rate must be less than max heart rate';

  @override
  String get errInvalidPulseDuration =>
      'Pulse duration must be between 20 and 1000 ms';

  @override
  String get unsavedTitle => 'Unsaved changes';

  @override
  String get unsavedBody => 'Leaving will discard your changes. Continue?';

  @override
  String get unsavedDiscard => 'Discard';

  @override
  String get unsavedKeepEditing => 'Keep editing';

  @override
  String get savedToast => 'Settings saved';

  @override
  String get fixErrorsBeforeSave => 'Fix the highlighted fields first';

  @override
  String get fieldMqttTls => 'Use TLS (mqtts)';

  @override
  String get fieldMqttLwtTopic => 'Last-will topic (optional)';

  @override
  String get hintMqttLwt =>
      'Publishes an offline message to this topic on abnormal disconnect';

  @override
  String get hintClientId => 'Uses a default client ID when empty';

  @override
  String get showPassword => 'Show password';

  @override
  String get onbSkip => 'Skip';

  @override
  String get onbNext => 'Next';

  @override
  String get onbDone => 'Get started';

  @override
  String get onbTitle1 => 'Welcome to HR PUSH';

  @override
  String get onbBody1 =>
      'Read live heart rate from your strap or watch and push it to HTTP/WebSocket, VRChat OSC and MQTT.';

  @override
  String get onbTitle2 => 'Connect a device';

  @override
  String get onbBody2 =>
      'Wear your heart rate device and tap it under \"Nearby devices\" to connect.\n\nXiaomi/Redmi watches: enable \"Heart Rate Broadcast\" on the watch first (Settings → Heart Rate).';

  @override
  String get onbTitle3 => 'Set up push';

  @override
  String get onbBody3 =>
      'Open Settings to enter your webhook, OSC or MQTT address. Use the Test button to verify connectivity; data pushes in real time after saving.';

  @override
  String get stPermissionFailed => 'Permission check failed';

  @override
  String get stConnectFailed => 'Connection failed';

  @override
  String get stWaitingBroadcast => 'Waiting for device broadcast...';

  @override
  String get stReconnectGaveUp =>
      'Auto reconnect failed; please pick the device manually';

  @override
  String get stWaitingRebroadcast =>
      'Waiting for the device to advertise again...';

  @override
  String get stHrServiceMissingXiaomi =>
      'Heart rate service not found; enable \"Heart Rate Broadcast\" on the watch';

  @override
  String get stHrServiceMissing =>
      'Device does not expose the standard heart rate service';

  @override
  String get stConnectedSubscribing =>
      'Connected, subscribing to heart rate...';

  @override
  String get stDisconnecting => 'Disconnecting...';

  @override
  String get stDisconnectedDone => 'Disconnected';

  @override
  String get stResubscribeFailedReconnecting =>
      'Subscribe failed, reconnecting...';

  @override
  String get stSubscribing => 'Subscribing to heart rate...';

  @override
  String get stDiscovering => 'Discovering services...';

  @override
  String get stSubscribeRetrying => 'Retrying subscription...';

  @override
  String get stSubscribeFailed => 'Subscription failed';

  @override
  String get stConnectTimeout => 'Connection timed out';

  @override
  String get stConnectCancelled => 'Connection cancelled';

  @override
  String get stDeviceDisconnected => 'Device disconnected';

  @override
  String get btnHrPercentHelp => 'Percent conversion guide';

  @override
  String get percentHelpTitle => 'Heart rate percent';

  @override
  String get percentHelpFormulaTitle => 'Formula';

  @override
  String get percentHelpFormulaBody =>
      'percent = (BPM − min HR) ÷ (max HR − min HR)\n\nThe result is a float between 0.0 and 1.0: 0.0 at the min HR, 1.0 at the max HR, and clamped outside the range. The defaults (min 0, max 200) are equivalent to BPM ÷ 200.';

  @override
  String get percentHelpExampleTitle => 'Live examples';

  @override
  String percentHelpExampleIntro(int min, int max) {
    return 'Converted with the current settings (min $min, max $max):';
  }

  @override
  String get percentHelpTagMin => 'Min';

  @override
  String get percentHelpTagMid => 'Midpoint';

  @override
  String get percentHelpTagMax => 'Max';

  @override
  String get percentHelpTagClampedLow => 'Below min → clamped to 0';

  @override
  String get percentHelpTagClampedHigh => 'Above max → clamped to 1';

  @override
  String get percentHelpFieldsTitle => 'Push fields';

  @override
  String get percentHelpFieldJson =>
      'HTTP/WS/MQTT: the percent field in the JSON payload, float 0~1';

  @override
  String get percentHelpFieldOsc =>
      'OSC: /avatar/parameters/hr_percent, float 0~1';

  @override
  String get percentHelpFieldChatbox =>
      'ChatBox template percent placeholder: rendered as an integer 0~100';

  @override
  String get percentHelpUnityTitle => 'Unity / VRChat mapping';

  @override
  String get percentHelpUnityIntro =>
      'Unity tools often remap the percent to 0~255 (8-bit). Two input conventions are common:';

  @override
  String get percentHelpUnity01 =>
      'Tool expects 0~1 input: value × 255 (e.g. 0.5 → 128)';

  @override
  String get percentHelpUnityNeg =>
      'Tool expects -1~1 input: remap (value × 2 − 1) onto 0~255 (e.g. 0.5 → 191)';

  @override
  String get percentHelpUnityDirect =>
      'Float animator parameters: feed 0~1 directly, no conversion needed';

  @override
  String get percentHelpWhyTitle => 'Why set a min HR';

  @override
  String get percentHelpWhyBody =>
      'With a min of 0, a resting rate of 60 BPM already reads 0.3, so daily variation only spans 0.3~1.0. Setting the min to your everyday resting rate (e.g. 60) lets 0.0~1.0 cover your actual range, making animations more expressive.';
}
