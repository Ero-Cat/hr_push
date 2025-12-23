# HR PUSH / Heart Rate Push

![Release](https://img.shields.io/github/v/release/Ero-Cat/hr_push?display_name=tag)
![License](https://img.shields.io/github/license/Ero-Cat/hr_push)
![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-0ea5e9)
![Protocols](https://img.shields.io/badge/Protocols-HTTP%2FWS%20%7C%20OSC%20%7C%20MQTT-10b981)
![BLE](https://img.shields.io/badge/BLE-Heart%20Rate-ef4444)

[中文](README.md) | **English** | [日本語](README_JA.md)

A cross-platform BLE heart rate monitor and push tool built with Flutter. After connecting a heart rate device, it can sync real-time BPM, online status, and heart-rate percentage to **HTTP/WS, OSC, and MQTT**.

<div align="center">
  <img src="images/logo.png" alt="HR PUSH logo" width="140" />
</div>

## 🗺️ Use Cases
- **Always-on push**: Run on a Mac mini or Windows PC that stays on. When your watch is in range with HR broadcasting enabled, the app connects and keeps pushing.
- **VRChat / custom apps**: Subscribe via OSC or HTTP/WS/MQTT to drive parameters, UI, or custom integrations.

## 📷 Preview

| Home | Settings |
| --- | --- |
| ![Home](images/main.png) | ![Settings](images/settings.png) |

## ✨ Key Features
- **BLE scan & connect**: Filters irrelevant advertisements and prioritizes heart-rate services / common wearables.
- **Smart auto reconnect**: Remembers the last device; auto-reconnects on disconnection or stale data.
- **Realtime display**: BPM, last update time, and RSSI. RSSI polling follows the refresh interval.
- **Multi-protocol push (optional)**
  - **HTTP/WS**: Provide `http(s)://` or `ws(s)://` to enable JSON payloads.
  - **OSC**: Provide `host:port` (empty disables); UI pre-fills `127.0.0.1:9000`.
  - **MQTT**: Provide broker address (empty disables); supports port/topic/user/pass/client ID.
- **Debug view**: Nearby advertisements, Service UUID, RSSI, manufacturer data length.
- **Desktop UX**: Fixed portrait window on Windows/macOS/Linux; Windows tray support.
- **Android persistent notification**: Shows heart rate and updates at the refresh interval.

## 🚀 Quick Start (User)
1. Open the app and tap “Rescan”.
2. Select a heart rate device and connect.
3. Fill in push targets (HTTP/WS, OSC, or MQTT) in Settings and save.

> If a device only broadcasts and cannot be connected, you can still see data in the “Broadcast Debug” view. Push happens only after connecting and subscribing.

## 🧰 Usage
### Connect & Reconnect
- “Rescan” refreshes nearby devices.
- “Quick Connect” prioritizes devices with better RSSI or recent appearances.
- If heart rate hasn’t updated for an extended period, it will be treated as offline and auto-reconnected.

### Payload Format
All protocols use the same JSON payload.

- Heart rate event
```json
{
  "event": "heartRate",
  "heartRate": 85,
  "percent": 0.42,
  "connected": true,
  "device": "Polar H10",
  "timestamp": "2025-12-12T09:00:00.000Z"
}
```

- Connection event
```json
{
  "event": "connection",
  "connected": false,
  "device": "Polar H10",
  "timestamp": "2025-12-12T09:05:00.000Z"
}
```

`percent = heartRate / maxHeartRate`, range 0-1.

### Config Options
| Option | Description | Default |
| --- | --- | --- |
| HTTP/WS Push URL | Empty disables; supports `http(s)` / `ws(s)` | empty |
| OSC Target | `host:port`; empty disables; UI pre-fills | empty (recommended `127.0.0.1:9000`) |
| OSC Path: online | bool | `/avatar/parameters/hr_connected` |
| OSC Path: BPM | int | `/avatar/parameters/hr_val` |
| OSC Path: percent | float 0-1 | `/avatar/parameters/hr_percent` |
| OSC ChatBox toggle | When enabled, send text to `/chatbox/input` | off |
| OSC ChatBox template | Supports `{hr}`/`{percent}`; max 144 chars / 9 lines | `💓{hr}` |
| MQTT Broker | Empty disables; `mqtt://host:port` or host | empty |
| MQTT Port | Used when broker has no port | `1883` |
| MQTT Topic | JSON payload topic | `hr_push` |
| MQTT Username/Password | Optional | empty |
| MQTT Client ID | Auto-generated when empty | empty |
| Max Heart Rate | Used for percent | `200` |
| Push/Refresh Interval (ms) | UI refresh, push throttling, RSSI polling | `1000` |

## 🎮 VRChat (OSC)
- Recommended OSC parameter plugin: [booth.pm/zh-cn/items/5531594](https://booth.pm/zh-cn/items/5531594)
- Or listen to the OSC paths in your avatar parameters.

### Screenshots
<img src="images/vrchat.png" alt="VRChat OSC" width="900" />

#### Android status bar
<img src="images/android.jpeg" alt="Android" />

## 🧩 Device Compatibility
### Verified Devices
**Broadcaster (HR device)**
1. Garmin Enduro 2

**Receiver**
1. iPhone 15 Pro (self-signed)
2. OnePlus Ace (ColorOS / Android 14)
3. MacBook Pro M5 (macOS Tahoe 26.1)
4. Windows (B450I GAMING PLUS AC Bluetooth)

### Known Limitations
- **Mi Smart Band series**: Devices usually do not expose standard BLE Heart Rate Service and rely on proprietary/authenticated protocols, so they cannot be accessed via generic BLE heart-rate characteristics.

## 🛡️ Platform Support & Permissions
- **Android**: BLE scan/connect permission required (Android 12+ no location required; 11 and below need location). For persistent notification on Android 13+, allow notification permission.
  - ColorOS / some OEM ROMs: enable notifications and allow background/autostart, otherwise persistent card or background updates may not work.
- **iOS/macOS**: Bluetooth permission is requested on first launch.

## 🔧 Dev & Build
- Main code: `lib/main.dart` (UI), `lib/heart_rate_manager.dart` (scan/connect/subscribe/push).
- Install deps: `flutter pub get`.
- Run: `flutter run -d <device>`.
- Test: `flutter test`.
- Build: `flutter build apk|ios|windows|macos|linux`.
- Style: 2-space indent; `dart format .`; `flutter_lints` enabled.

## ⚠️ Known Issues
- On Windows, running under a non-ASCII path may fail. Use an ASCII path if possible.

## 🧾 Changelog
### v1.3.4
- OSC: ChatBox heart-rate push with `{hr}/{percent}` templates and throttling/dedup.
- UI: ChatBox toggle and template input; removed old ChatBox suggestion text.
- Docs & repo: README restructure; MIT License added; .gitignore ignores local release script.

### v1.3.3
- UI: App title unified to “Heart Rate Push”.
- UI: Home/Settings layout adjustments; unified button styles.
- OSC: Force sync online status when pushing heart rate.
- Android: Notification channel updated.
- CI: Remove unsigned iOS build in release workflow.
- Release: Artifact naming unified with `hr-push` prefix (macOS/Windows).
- Docs: VRChat/Android screenshots; tested devices list; Windows non-ASCII path issue.
- Assets: Replace screenshots.
- Dev: Ignore `.vscode/settings.json`; update test titles.

### v1.3.1
- Windows: Click tray icon to restore window.
- Windows: More stable reconnect after disconnect.
- UI: Fewer rebuilds, smoother interaction.
- OSC: `/avatar/parameters/hr_connected` aligns with actual online state.

### v1.3.0
- Added MQTT push.
- Android: Persistent heart-rate notification.
- RSSI polling follows refresh interval.
- Reconnect logic fixes to avoid deadlocks.
- Windows: BLEServer more stable under non-ASCII usernames/paths.

### v1.2.2
- Windows: Minimize to tray with hover status.
- Android: Release builds enable R8/resource shrink/ABI split; Windows/macOS/iOS link-time optimization.

### v1.2.1
- Windows: Auto reconnect when data is stale.

### v1.2.0
- Unified app icons from `images/logo.png`.
- Windows: Pause heartbeat animation when unfocused; auto reconnect on stale data.
- README: Added Windows path build note.
- Dependency: `flutter_launcher_icons` desktop support.

## 📜 License
MIT License. See `LICENSE`.

## 🌐 Other Languages
- Chinese: [README.md](README.md)
- Japanese: [README_JA.md](README_JA.md)

## 🤝 Contributing
Issues and PRs are welcome. Please include logs and environment details when reporting device/platform issues.
