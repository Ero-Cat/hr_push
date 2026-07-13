# OSC Background Reliability and Heartbeat Configuration Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Keep Android monitoring alive with a real foreground service, simplify the dashboard, and make the three VRChat heartbeat animation outputs independently configurable with an adjustable pulse duration.

**Architecture:** Persist the new heartbeat options in `HeartRateSettings`, pass them through `PushCoordinator` into `OscService`, and keep OSC timing isolated inside the service. Move Android notification ownership from `MainActivity` into a dedicated `HrForegroundService`; retain a small method-channel bridge for lifecycle updates and battery-optimization settings. Flutter settings remain Cupertino-first and reuse the repository's localization pipeline.

**Tech Stack:** Flutter/Dart, Cupertino widgets, SharedPreferences, UDP OSC, Kotlin Android foreground services, Flutter method channels, `flutter_test`.

---

## File Map

- Modify `lib/models/heart_rate_settings.dart`: persisted heartbeat enable flags and pulse duration.
- Modify `lib/services/osc_service.dart`: enabled-output filtering, configured pulse duration, deterministic clamping, and transition cleanup.
- Modify `lib/services/push_coordinator.dart`: rebuild OSC service when new options change and pass them into the service.
- Modify `lib/pages/settings_page.dart`: switches, conditional address rows, duration field, and background-runtime action.
- Modify `lib/pages/heart_dashboard.dart`: remove the OSC status strip and unused imports.
- Modify `lib/hr_notification_service.dart`: foreground-service start/update/stop and battery-optimization bridge methods.
- Modify `lib/heart_rate_manager.dart`: start service after BLE readiness regardless of notification permission and stop it on disposal.
- Create `android/app/src/main/kotlin/moe/iacg/hrpush/HrForegroundService.kt`: foreground service and notification rendering.
- Modify `android/app/src/main/kotlin/moe/iacg/hrpush/MainActivity.kt`: method-channel routing and battery-optimization intents.
- Modify `android/app/src/main/AndroidManifest.xml`: foreground-service and battery-optimization permissions plus service declaration.
- Modify `lib/l10n/app_zh.arb`, `lib/l10n/app_en.arb`, `lib/l10n/app_ja.arb`: functional OSC labels and background-runtime copy.
- Regenerate `lib/l10n/app_localizations*.dart` with `flutter gen-l10n`.
- Modify `test/models/heart_rate_settings_test.dart`: defaults and persistence.
- Modify `test/services/osc_service_test.dart`: output switches and pulse timing.
- Modify `test/services/push_coordinator_test.dart`: live application of option changes.
- Create `test/pages/heart_dashboard_test.dart`: OSC strip absence.
- Create `test/pages/settings_page_test.dart`: settings controls and labels.
- Modify `test/android_manifest_test.dart`: manifest and Kotlin source contract.

### Task 1: Persist Heartbeat Configuration

**Files:**
- Modify: `test/models/heart_rate_settings_test.dart`
- Modify: `lib/models/heart_rate_settings.dart`

- [ ] **Step 1: Write failing model tests**

Add expectations that defaults enable all outputs with a 120 ms pulse and that custom values survive `save`/`fromPrefs`:

```dart
expect(settings.oscHeartbeatIntEnabled, isTrue);
expect(settings.oscHeartbeatPulseEnabled, isTrue);
expect(settings.oscHeartbeatToggleEnabled, isTrue);
expect(settings.oscHeartbeatPulseDurationMs, 120);
```

Use `copyWith` to set all switches to `false` and duration to `360`, save,
restore, and compare the four restored fields individually. Do not add model
object equality solely for this test.

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/models/heart_rate_settings_test.dart`

Expected: compile failures because the four settings members and `copyWith` arguments do not exist.

- [ ] **Step 3: Implement model fields and persistence**

Add required constructor fields, final members, defaults, preference keys, `fromPrefs`, `save`, and `copyWith` support:

```dart
static const _defaultHeartbeatIntEnabled = true;
static const _defaultHeartbeatPulseEnabled = true;
static const _defaultHeartbeatToggleEnabled = true;
static const _defaultHeartbeatPulseDurationMs = 120;
```

Preserve existing stored path keys and use the defaults when the new keys are absent.

- [ ] **Step 4: Run tests and verify GREEN**

Run: `flutter test test/models/heart_rate_settings_test.dart`

Expected: all model tests pass.

- [ ] **Step 5: Commit**

```bash
git add lib/models/heart_rate_settings.dart test/models/heart_rate_settings_test.dart
git commit -m "Add configurable OSC heartbeat settings"
```

### Task 2: Apply Output Switches and Pulse Duration

**Files:**
- Modify: `test/services/osc_service_test.dart`
- Modify: `test/services/push_coordinator_test.dart`
- Modify: `lib/services/osc_service.dart`
- Modify: `lib/services/push_coordinator.dart`

- [ ] **Step 1: Write failing OSC service tests**

Construct `OscService` with explicit flags and duration. Add tests that:

```dart
heartbeatIntEnabled: false,
heartbeatPulseEnabled: true,
heartbeatToggleEnabled: false,
heartbeatPulseDuration: const Duration(milliseconds: 40),
```

- receives no integer or toggle packets;
- receives boolean `true`, followed by `false` after at least 40 ms;
- clamps a configured duration longer than a 600 ms RR interval so `false` arrives before the next `true`;
- emits final integer/boolean inactive values when stopping an active pulse;
- emits no inactive packets for outputs that were disabled from construction.

- [ ] **Step 2: Run service tests and verify RED**

Run: `flutter test test/services/osc_service_test.dart`

Expected: compile failures because `OscService` does not accept enable flags or a duration.

- [ ] **Step 3: Implement minimal OSC behavior**

Add final configuration members to `OscService`. Guard `_sendHeartbeatActive` and `_sendHeartbeatInactive` per enabled output. Replace `_qrsIntervalFor` with:

```dart
Duration _pulseDurationFor(int bpm) {
  final rrMs = _rrIntervalFor(bpm).inMilliseconds;
  final configuredMs = heartbeatPulseDuration.inMilliseconds;
  return Duration(milliseconds: min(configuredMs, max(1, rrMs - 1)));
}
```

Import `dart:math`. Keep toggle initialized to `false`, emit it, then flip after the pulse completes.

- [ ] **Step 4: Pass settings through the coordinator**

Include all four new settings in `oscChanged` and `_getOscService`. Before disposing a changed OSC service, call an async cleanup method that sends inactive values only for enabled blink outputs, then dispose after cleanup. Keep update application non-blocking with `unawaited`.

- [ ] **Step 5: Write coordinator live-update test**

Start with integer enabled, change settings to integer disabled and boolean enabled with a different duration, send another heart rate, and assert subsequent packet types follow the new settings without restarting the coordinator.

- [ ] **Step 6: Run focused tests and verify GREEN**

Run: `flutter test test/services/osc_service_test.dart test/services/push_coordinator_test.dart`

Expected: all OSC tests pass without timeout or stray packets.

- [ ] **Step 7: Commit**

```bash
git add lib/services/osc_service.dart lib/services/push_coordinator.dart test/services/osc_service_test.dart test/services/push_coordinator_test.dart
git commit -m "Make OSC heartbeat animation configurable"
```

### Task 3: Update Settings UI and Localization

**Files:**
- Create: `test/pages/settings_page_test.dart`
- Modify: `lib/pages/settings_page.dart`
- Modify: `lib/l10n/app_zh.arb`
- Modify: `lib/l10n/app_en.arb`
- Modify: `lib/l10n/app_ja.arb`
- Regenerate: `lib/l10n/app_localizations.dart`
- Regenerate: `lib/l10n/app_localizations_zh.dart`
- Regenerate: `lib/l10n/app_localizations_en.dart`
- Regenerate: `lib/l10n/app_localizations_ja.dart`

- [ ] **Step 1: Write failing settings widget test**

Pump `SettingsPage` inside a localized `CupertinoApp`. Assert Chinese functional labels are present and `参数` is absent. Toggle integer blinking off and verify its address field disappears while boolean and toggle controls remain.

Also enter `5000` in the duration field, save, and assert the returned setting is normalized to `120`.

- [ ] **Step 2: Run widget test and verify RED**

Run: `flutter test test/pages/settings_page_test.dart`

Expected: label and switch expectations fail because the controls do not exist.

- [ ] **Step 3: Add localized functional copy**

Rename OSC fields in all three ARB files without `参数`, `Param`, or `パラメータ`. Add keys for integer blink, boolean blink, beat toggle, blink duration, background runtime protection, and the action button.

- [ ] **Step 4: Regenerate localization classes**

Run: `flutter gen-l10n`

Expected: generated localization Dart files expose the new getters.

- [ ] **Step 5: Implement Cupertino settings controls**

Add state booleans initialized from `widget.initial`, one numeric duration controller, and three `CupertinoFormRow` + `CupertinoSwitch` rows. Render each address input only while its output is enabled. Preserve address controller contents while disabled.

Normalize duration on save:

```dart
final duration = int.tryParse(_oscHeartbeatDurationCtrl.text.trim());
final normalizedDuration = duration != null && duration >= 20 && duration <= 1000
    ? duration
    : 120;
```

Add a background-runtime action row that calls `HrNotificationService.openBackgroundRuntimeSettings()` on Android and is hidden elsewhere.

- [ ] **Step 6: Run widget test and verify GREEN**

Run: `flutter test test/pages/settings_page_test.dart`

Expected: all settings UI tests pass.

- [ ] **Step 7: Commit**

```bash
git add lib/pages/settings_page.dart lib/l10n test/pages/settings_page_test.dart
git commit -m "Improve VRChat OSC settings controls"
```

### Task 4: Remove Dashboard OSC Status Strip

**Files:**
- Create: `test/pages/heart_dashboard_test.dart`
- Modify: `lib/pages/heart_dashboard.dart`

- [ ] **Step 1: Write failing dashboard widget test**

Pump `HeartDashboard` with a `HeartRateManager` provider in the Flutter test environment and assert `oscStatusTitle` is absent while the hero and nearby-device content still render.

- [ ] **Step 2: Run test and verify RED**

Run: `flutter test test/pages/heart_dashboard_test.dart`

Expected: fails because the OSC status title is still rendered.

- [ ] **Step 3: Remove dashboard-only status UI**

Delete `_OscStatusStrip`, its spacing, and the unused `push_coordinator.dart` import. Keep OSC status state in the manager for logs and service behavior.

- [ ] **Step 4: Run test and verify GREEN**

Run: `flutter test test/pages/heart_dashboard_test.dart`

Expected: dashboard test passes.

- [ ] **Step 5: Commit**

```bash
git add lib/pages/heart_dashboard.dart test/pages/heart_dashboard_test.dart
git commit -m "Remove OSC status from dashboard"
```

### Task 5: Add Android Foreground Service and Battery Settings

**Files:**
- Modify: `test/android_manifest_test.dart`
- Create: `android/app/src/main/kotlin/moe/iacg/hrpush/HrForegroundService.kt`
- Modify: `android/app/src/main/kotlin/moe/iacg/hrpush/MainActivity.kt`
- Modify: `android/app/src/main/AndroidManifest.xml`

- [ ] **Step 1: Write failing Android contract tests**

Read the manifest and Kotlin sources as text. Assert the manifest contains:

```text
android.permission.FOREGROUND_SERVICE
android.permission.FOREGROUND_SERVICE_CONNECTED_DEVICE
android.permission.REQUEST_IGNORE_BATTERY_OPTIMIZATIONS
android:foregroundServiceType="connectedDevice"
.HrForegroundService
```

Assert the service calls `startForeground`, and the activity handles `startForegroundService`, `stopForegroundService`, and `openBackgroundRuntimeSettings`. Assert battery handling includes `isIgnoringBatteryOptimizations`, `ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`, `ACTION_IGNORE_BATTERY_OPTIMIZATION_SETTINGS`, and `ACTION_APPLICATION_DETAILS_SETTINGS`.

- [ ] **Step 2: Run contract tests and verify RED**

Run: `flutter test test/android_manifest_test.dart`

Expected: failures for missing permissions, service, and Kotlin methods.

- [ ] **Step 3: Declare Android service and permissions**

Add the three permissions and a non-exported foreground service with `connectedDevice` type to the main manifest.

- [ ] **Step 4: Create `HrForegroundService`**

Move notification-channel creation, `RemoteViews`, and notification building from `MainActivity` into the service. Implement action constants for update and stop. Call `startForeground` immediately in `onStartCommand`, update notification extras, return `START_STICKY`, and remove the notification in `onDestroy`/stop handling.

- [ ] **Step 5: Reduce `MainActivity` to a bridge**

Route `startForegroundService` through `ContextCompat.startForegroundService`, send updates with `startService`, stop with `stopService`, and implement the battery-optimization intent chain defined in the spec. Return structured success/failure to Dart and never crash when no settings activity resolves.

- [ ] **Step 6: Run Android contract tests and build Kotlin**

Run: `flutter test test/android_manifest_test.dart`

Run: `flutter build apk --debug`

Expected: tests pass and debug APK builds successfully.

- [ ] **Step 7: Commit**

```bash
git add android/app/src/main test/android_manifest_test.dart
git commit -m "Run Android monitoring as a foreground service"
```

### Task 6: Integrate Foreground-Service Lifecycle

**Files:**
- Modify: `lib/hr_notification_service.dart`
- Modify: `lib/heart_rate_manager.dart`
- Create: `test/hr_notification_service_test.dart`
- Modify: `test/pages/settings_page_test.dart`

- [ ] **Step 1: Add failing method-channel contract tests**

Use `TestDefaultBinaryMessengerBinding` to capture method calls from `HrNotificationService`. Verify `start`, `showConnected`, `showDisconnected`, `openBackgroundRuntimeSettings`, and `stop` invoke the expected native method names and payloads. Guard Android-only behavior through an injectable platform predicate or a small channel wrapper so tests do not depend on the host OS.

- [ ] **Step 2: Run tests and verify RED**

Run: `flutter test test/hr_notification_service_test.dart`

Expected: compile failures for the new service lifecycle methods or test seam.

- [ ] **Step 3: Implement Dart bridge**

Add `start()`, `stop()`, and `openBackgroundRuntimeSettings()` while retaining notification permission management. Make method-channel errors return `false` and log through `debugPrint` without throwing into BLE startup.

- [ ] **Step 4: Integrate manager startup and disposal**

After `_ensurePermissionsAndBluetooth()` succeeds, initialize notification support and start the foreground service on Android before scanning. Request notification permission independently; denial updates user-facing status but does not stop the foreground service. A native foreground-service start failure is logged but also does not abort scanning or reconnection. Replace `cancel()` with `stop()` in `dispose`.

- [ ] **Step 5: Run focused tests and verify GREEN**

Run: `flutter test test/hr_notification_service_test.dart test/pages/settings_page_test.dart`

Expected: all bridge and settings tests pass.

- [ ] **Step 6: Format and regenerate**

Run: `dart format lib test`

Run: `flutter gen-l10n`

Expected: no formatting changes remain after a second format check.

- [ ] **Step 7: Run full verification**

Run: `flutter test`

Run: `flutter analyze`

Run: `flutter build apk --debug`

Expected: all tests pass, analysis reports no issues introduced by this change, and the Android debug APK builds.

- [ ] **Step 8: Commit**

```bash
git add lib test android
git commit -m "Integrate Android background runtime protection"
```
