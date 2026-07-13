# Android Background Reliability and OSC Heartbeat Configuration

## Goal

Improve long-running Android monitoring reliability, remove the OSC delivery
status strip from the dashboard, and make VRChat heartbeat animation outputs
independently configurable with clearer labels.

## Root Cause

OSC uses UDP and does not maintain a persistent connection. The current Android
notification is posted directly by the activity and is not backed by a
foreground service. When the app is backgrounded or the screen is locked,
Android or an OEM power manager can deprioritize or terminate the process,
which stops the Dart timers, BLE session, and OSC output together.

The notification must be moved to a real foreground service. Standard Android
battery-optimization controls should be exposed as an additional user action.
Vendor-specific settings intents will not be maintained because they are not a
stable Android API and change between ROM versions.

## Android Background Runtime

- Add a native Android foreground service that owns the existing ongoing heart
  rate notification.
- Declare the foreground-service permissions and a `connectedDevice` service
  type required by current Android versions.
- Start the foreground service after BLE runtime permissions have been granted
  and the adapter readiness check succeeds. On Android 14 this guarantees the
  `BLUETOOTH_CONNECT` prerequisite is satisfied before starting a
  `connectedDevice` foreground service.
- Notification permission denial does not block the service. Android can run a
  foreground service without `POST_NOTIFICATIONS`, although the notification
  may only be visible in the system's active-apps surface.
- Update the running service through the existing method channel when the BLE
  connection or heart rate changes.
- Keep the service running while the `HeartRateManager` is active, including
  disconnected scanning and automatic reconnection states. Stop it when the
  manager is disposed or the app explicitly shuts monitoring down.
- Add a method-channel action that first checks
  `PowerManager.isIgnoringBatteryOptimizations(packageName)`. When exemption is
  still needed, launch `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS` with the
  application's package URI.
- Declare `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`. If the direct request intent
  cannot be resolved, try `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, then
  fall back to `ACTION_APPLICATION_DETAILS_SETTINGS`. If the app is already
  exempt, report success without opening a system screen.
- Expose this action in Settings as `后台运行保障` and its localized equivalents.
- Do not add wake locks, exact alarms, boot receivers, or vendor-specific
  activity intents.

The foreground service raises process priority but cannot guarantee survival
after a force-stop, device reboot, or an OEM policy that explicitly blocks the
application. The settings action gives users a standard recovery path for
those devices.

## Dashboard

Remove the OSC status strip and its dashboard-only status presentation code.
OSC sending and diagnostic logging remain unchanged. The dashboard will flow
directly from the heart-rate hero to the nearby-device list.

## VRChat OSC Configuration

Retain the existing OSC address fields while replacing implementation-oriented
labels with functional labels. Chinese labels are:

- `接收地址`
- `在线状态地址`
- `实时心率地址`
- `心率比例地址`
- `整数闪烁`
- `布尔闪烁`
- `逐拍翻转`
- `闪烁时长 (ms)`
- `最大心率`

Equivalent concise labels will be provided for English and Japanese. The word
`参数`, `Param`, or `パラメータ` will not appear in these labels.

Add these persisted settings:

- `oscHeartbeatIntEnabled`, default `true`
- `oscHeartbeatPulseEnabled`, default `true`
- `oscHeartbeatToggleEnabled`, default `true`
- `oscHeartbeatPulseDurationMs`, default `120`

Each heartbeat output has a Cupertino switch. Its address field is visible only
while enabled. Existing stored paths remain intact when an output is disabled,
so re-enabling restores the user's address.

The duration field accepts 20 through 1000 milliseconds. Invalid values are
normalized to the default when saving. At runtime, the active duration is
clamped below the current RR interval so an inactive value is emitted before
the next beat.

## OSC Behavior

On every generated beat:

- Integer blink sends `1`, then sends `0` after the configured duration.
- Boolean blink sends `true`, then sends `false` after the configured duration.
- Beat toggle alternates its boolean value once per beat.
- Outputs that were already disabled send no packets. If integer or boolean
  blinking is disabled while a pulse is active, the old service sends one final
  inactive value (`0` or `false`) before it is disposed so the remote avatar is
  not left active. Beat toggle does not send a reset value.
- Changing any heartbeat option recreates the OSC service so changes take
  effect without restarting the app.
- Beat toggle starts at `false`, emits the current value on each beat, and then
  flips for the following beat. Recreating the OSC service resets it to
  `false`, preserving the current behavior.

The effective pulse duration is
`min(configuredDurationMs, max(1, rrIntervalMs - 1))`. This guarantees the
inactive transition is scheduled before the next generated beat and gives
tests a deterministic boundary.

Existing users retain all three enabled outputs and receive the 120 ms default
duration after upgrading.

## Error Handling

- Foreground-service and battery-settings method-channel failures are logged
  and must not stop BLE initialization.
- Notification permission denial continues to be reported without crashing.
- OSC output remains best effort because UDP delivery has no connection state.
- The settings page constrains duration input to numeric values and normalizes
  invalid or out-of-range values.

## Testing

- Model tests cover defaults, copy behavior, and SharedPreferences round trips
  for the new switches and duration.
- OSC service tests verify each disabled output, configured pulse duration, and
  runtime clamping below the RR interval.
- Coordinator tests verify that heartbeat option changes rebuild the service
  and apply without restart.
- Widget tests verify the dashboard no longer renders OSC status and the
  settings page renders the new controls and localized functional labels.
- Android source/manifest tests verify foreground-service permissions, service
  declaration, service type, and native start/stop handling.
- Run localization generation, Dart formatting, focused tests, the full Flutter
  test suite, and static analysis.
