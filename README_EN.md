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

## ✨ Highlights
- **BLE scan & connect**: Filters irrelevant advertisements and prioritizes heart-rate services / common wearables.
- **Smart auto reconnect**: Remembers the last device; auto-reconnects on disconnection or stale data.
- **Realtime display**: BPM, last update time, and RSSI. RSSI polling follows the refresh interval.
- **Multi-protocol push**: HTTP/WS, OSC, and MQTT can be enabled independently with a unified JSON payload.
- **Debug view**: Nearby advertisements, Service UUID, RSSI, manufacturer data length.
- **Desktop UX**: Fixed portrait window on Windows/macOS/Linux; Windows tray support.
- **Android persistent notification**: Shows heart rate and connection status in the notification bar.

## 🗺️ Use Cases
- **Always-on push**: Run on a Mac mini or Windows PC that stays on. When your watch is in range with HR broadcasting enabled, the app connects and keeps pushing.
- **VRChat / custom apps**: Subscribe via OSC or HTTP/WS/MQTT to drive parameters, UI, or custom integrations.

## 📷 Preview

| Home | Settings |
| --- | --- |
| ![Home](images/main.png) | ![Settings](images/settings.png) |

## 🚀 Quick Start (User)
1. Open the app and tap “Rescan”.
2. Select a heart rate device and connect.
3. Fill in push targets (HTTP/WS, OSC, or MQTT) in Settings and save.

> If a device only broadcasts and cannot be connected, you can still see data in the “Broadcast Debug” view. Push happens only after connecting and subscribing.

## 🔗 Protocols & Data
### Protocols
- **HTTP**: POST JSON to `http(s)://` endpoints (3s timeout).
- **WebSocket**: Send JSON text to `ws(s)://` endpoints, auto-reconnects on disconnect.
- **OSC**: Send UDP messages to `host:port`, supports bool/int/float and ChatBox text.
- **MQTT**: Enable by broker address; supports port/topic/user/pass/client ID, publishes with QoS 1.

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

## ⚙️ Settings
| Item | Description | Default |
| --- | --- | --- |
| HTTP/WS endpoint | Empty disables; supports `http(s)`/`ws(s)` | Empty |
| OSC target | `host:port`, empty disables, UI prefill | Empty (suggested `127.0.0.1:9000`) |
| OSC path: connected | Sends bool | `/avatar/parameters/hr_connected` |
| OSC path: bpm | Sends int BPM | `/avatar/parameters/hr_val` |
| OSC path: percent | Sends float 0-1 | `/avatar/parameters/hr_percent` |
| OSC ChatBox toggle | Sends text to `/chatbox/input` | Off |
| OSC ChatBox template | `{hr}`/`{percent}`, max 144 chars / 9 lines | `💓{hr}` |
| MQTT Broker | Empty disables; `mqtt://host:port` or host | Empty |
| MQTT Port | Used when broker has no port | `1883` |
| MQTT Topic | Publishes JSON payload | `hr_push` |
| MQTT User/Pass | Optional | Empty |
| MQTT Client ID | Auto-generated when empty | Empty |
| Max heart rate | For percent calculation | `200` |
| Update interval (ms) | UI refresh, push throttle, RSSI poll | `1000` |

## 🎮 VRChat (OSC)
- Recommended OSC parameter plugin: [booth.pm/zh-cn/items/5531594](https://booth.pm/zh-cn/items/5531594)
- Or listen to the OSC paths directly in your avatar.

### Screenshots
<img src="images/vrchat.png" alt="VRChat OSC" width="900" />

#### Android notification bar
<img src="images/android.jpeg" alt="Android" />

## 🧩 Device Compatibility
### Verified devices
**BLE broadcast senders**
1. Garmin Enduro 2 (watch HR broadcast)
2. Xiaomi Smart Band 9 (enable HR broadcast in settings after firmware 1.3.206+; older bands may be unsupported or untested)

**BLE broadcast receivers**
1. iPhone 15 Pro (self-signing supported)
2. OnePlus Ace (ColorOS / Android 14)
3. MacBook Pro M5 (macOS Tahoe 26.1)
4. Windows (B450I GAMING PLUS AC Bluetooth)

## 🛡️ Platform Support & Permissions
- **Android**: BLE scan/connect permissions required (Android 12+ without location, Android 11 and below require location). Android 13+ needs notification permission for the persistent card.
  - ColorOS / some OEM ROMs: allow notifications, background, and auto-start to keep the notification alive.
- **iOS/macOS**: Bluetooth permission will be requested on first launch.

## 🔧 Development & Build
- Core code: `lib/main.dart` (UI), `lib/heart_rate_manager.dart` (scan/connect/push).
- Install deps: `flutter pub get`.
- Run: `flutter run -d <device>`.
- Tests: `flutter test`.
- Build: `flutter build apk|ios|windows|macos|linux`.
- Style: 2-space indent; `dart format .`; `flutter_lints`.

## ⚠️ Known Issues
- On Windows, running from non-ASCII paths may fail. Prefer an ASCII-only path.

## 🧾 Changelog
### v1.4.0
- Android: status/navigation bar color sync and immersive refresh optimized (including OEM ROMs).
- Android: persistent notification channel + style upgraded; permission and color config more stable.
- Android: Play Core updated for targetSdk 34 (migrated to feature-delivery), release signing improved.
- Performance: UI refresh throttling to reduce unnecessary rebuilds.
- Engineering: package name unified to `moe.iacg.hrpush` on all platforms.

### v1.3.4
- OSC: ChatBox heart rate push with `{hr}/{percent}` templates and throttle/dedupe to prevent spam.
- UI: ChatBox toggle and template input; removed old ChatBox tips.
- Docs & repo: README restructure; MIT License added; .gitignore updated for local release scripts.

### v1.3.3
- UI: App title unified as “Heart Rate Push” (desktop title, iOS display name, test strings).
- UI: Home/Settings layout tweaks; unified style for Settings/Save buttons.
- OSC: Force sync online status when pushing heart rate to avoid stale state.
- Android: Notification channel updated to avoid old channel conflicts.
- CI: Removed unsigned iOS step in release flow.
- Release: Output naming unified to `hr-push` prefix (macOS/Windows).
- Docs: New/updated VRChat & Android screenshots, device list, and Windows path note.
- Assets: Replaced main/settings/VRChat screenshots.
- Dev: Ignore `.vscode/settings.json`, update test titles.

### v1.3.1
- Windows: Restore window on tray icon click.
- Windows: More stable auto-reconnect (scan hang recovery, candidate detection, stale handle cleanup).
- UI: Reduced unnecessary rebuilds for smoother interactions.
- OSC: `/avatar/parameters/hr_connected` now better reflects actual online state.

### v1.3.0
- Added MQTT push (enable by broker; configurable port/topic/auth).
- Android: Persistent heart rate notification card, auto-updates on refresh interval.
- RSSI polling interval aligned with update interval.
- Auto-reconnect logic and button state fixes to avoid deadlocks and duplicate connections.
- Windows: BLEServer more stable under non-ASCII usernames/paths (Public ASCII temp dir + correct working dir).

### v1.2.2
- Windows: Minimize to tray with status tooltip.
- Android: R8 minify/resource shrink/ABI splits; Windows/macOS/iOS link optimizations to reduce size.

### v1.2.1
- Windows: Auto-reconnect when heart rate data stalls.

### v1.2.0
- Unified app icon from `images/logo.png` across Windows/macOS/Android/iOS.
- Windows: Pause heartbeat animation when unfocused; auto-reconnect on stale data.
- README updated with Windows path caveat.
- Dependency sync: `flutter_launcher_icons` enabled for desktop platforms.

## 📜 License
MIT License. See `LICENSE` for details.

## 🌐 Multi-language README
- Chinese: [README.md](README.md)
- 日本語: [README_JA.md](README_JA.md)

## 🤝 Feedback
Issues and PRs are welcome. Please attach logs and environment info if possible.
