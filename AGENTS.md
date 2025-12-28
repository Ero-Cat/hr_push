# Repository Guidelines — HR PUSH

## Overview
**HR PUSH** is a cross-platform Flutter BLE heart rate monitor that pushes real-time BPM data to HTTP/WS, OSC, and MQTT endpoints. It targets Android, iOS, macOS, Windows, and Linux.

---

## Project Structure

```
hr_push/
├── lib/
│   ├── main.dart                    # App entry, routing, Provider setup
│   ├── heart_rate_manager.dart      # Core BLE, push, reconnect & settings logic (~2000 lines)
│   ├── hr_notification_service.dart # Android foreground notification
│   ├── app_log.dart                 # Loggy-based logging utility
│   │
│   ├── ble/                         # BLE abstraction layer
│   │   ├── ble_adapter.dart         # Platform-agnostic adapter interface
│   │   ├── ble_heart_rate_service.dart  # HR service discovery & subscription
│   │   └── universal_ble_adapter.dart   # universal_ble implementation
│   │
│   ├── pages/
│   │   ├── heart_dashboard.dart     # Main dashboard page
│   │   ├── settings_page.dart       # Push/OSC/MQTT config UI
│   │   └── log_detail_page.dart     # Debug log viewer
│   │
│   ├── widgets/
│   │   ├── hero_card.dart           # Heart rate display card with Lub-Dub animation
│   │   ├── nearby_list.dart         # Nearby BLE device list
│   │   └── glass_surface.dart       # Glassmorphism surface widget
│   │
│   ├── theme/
│   │   └── design_system.dart       # Colors, typography, spacing constants
│   │
│   └── l10n/                        # Internationalization
│       ├── app_*.arb                # Translation files (zh, en, ja)
│       └── app_localizations*.dart  # Generated localization classes
│
├── android/                         # Android platform shell
├── ios/                             # iOS platform shell
├── macos/                           # macOS platform shell
├── windows/                         # Windows platform shell
├── linux/                           # Linux platform shell
│
├── .github/workflows/release.yml    # CI: multi-platform release builds
├── pubspec.yaml                     # Dependencies & Flutter config
├── analysis_options.yaml            # Lint rules (flutter_lints)
├── l10n.yaml                        # Localization config
└── README.md / README_EN.md / README_JA.md
```

---

## Key Modules & Responsibilities

### `HeartRateManager` (lib/heart_rate_manager.dart)
- Central state manager (extends `ChangeNotifier`)
- BLE scanning, connection, auto-reconnect logic
- Heart rate parsing (standard BLE 0x180D/0x2A37)
- Multi-protocol push: HTTP/WS, OSC (UDP), MQTT
- Settings persistence via `SharedPreferences`
- Computes `hrOnline` status with staleness detection

### BLE Abstraction (`lib/ble/`)
- `BleAdapter` — abstract interface for platform independence
- `UniversalBleAdapter` — wraps `universal_ble` package (native WinRT on Windows)
- `BleHeartRateService` — service/characteristic discovery & subscription

### UI Components
- **Pages**: Dashboard, Settings, Log viewer
- **Widgets**: Animated heart card, device list, glassmorphism surfaces
- **Theme**: Centralized design tokens in `design_system.dart`

### Localization
- Supports: 简体中文 (zh), English (en), 日本語 (ja)
- Source files: `lib/l10n/app_*.arb`
- Generated via `flutter gen-l10n`

---

## Build & Development

### Prerequisites
- Flutter SDK ≥ 3.11.0
- For Windows: Visual Studio with C++ workload (Desktop development with C++)
- For macOS/iOS: Xcode with command-line tools

### Commands
```bash
# Install dependencies
flutter pub get

# Run on device
flutter run -d <device>

# Run tests
flutter test

# Build release artifacts
flutter build apk          # Android APK
flutter build appbundle    # Android AAB (Play Store)
flutter build ios          # iOS (requires signing)
flutter build macos        # macOS .app
flutter build windows      # Windows .exe
flutter build linux        # Linux binary

# Generate localization files
flutter gen-l10n

# Generate app icons (after modifying images/logo.png)
dart run flutter_launcher_icons
```

---

## Coding Conventions

### Dart Style
- **Indentation**: 2 spaces
- **Formatting**: Run `dart format .` before committing
- **Linting**: Enabled via `flutter_lints` in `analysis_options.yaml`
- **Variables**: Prefer `final` over `var` when value won't change
- **Naming**:
  - Files: `lowercase_with_underscores.dart`
  - Classes: `UpperCamelCase`
  - Methods/fields: `lowerCamelCase`
  - Private members: prefix with `_`

### Architecture Patterns
- **State Management**: Provider + ChangeNotifier (`HeartRateManager`)
- **Platform Abstraction**: Abstract classes in `lib/ble/` for testability
- **Widgets**: Prefer composition over inheritance; extract reusable components

### Comments
- Add comments only for non-obvious business logic
- Use `/// doc comments` for public APIs
- Mark TODOs with `// TODO(username): description`

---

## Testing

### Running Tests
```bash
flutter test                     # All tests
flutter test test/specific_test.dart  # Single file
```

### Test Organization
- Place tests under `test/` mirroring `lib/` structure
- Name: `<module>_test.dart` (e.g., `heart_rate_manager_test.dart`)
- Use `flutter_test` for widget tests
- Mock platform plugins; avoid real network calls

---

## Git & CI/CD

### Commit Messages
- Use imperative mood: `Add OSC ChatBox throttling`, `Fix Windows BLE reconnect`
- Keep subject ≤ 72 characters
- Reference issues when applicable: `Fix #42: handle empty device name`

### Branching
- `main` — stable release branch
- Feature branches: `feature/<description>`
- Bugfix branches: `fix/<description>`

### CI/CD
- **GitHub Actions** (`.github/workflows/release.yml`):
  - Triggers on tag push `v*`
  - Builds: Android APK/AAB, macOS, Windows, Linux
  - Uploads artifacts to release

### Versioning
- Semantic versioning: `MAJOR.MINOR.PATCH+BUILD`
- Update in `pubspec.yaml` → `version: x.y.z+n`
- Tag releases: `git tag v1.6.1 && git push origin v1.6.1`

---

## Security & Configuration

### Secrets
- **Never commit** API keys, passwords, or signing keys
- Push endpoints are user-configurable in-app; no hardcoded URLs
- MQTT credentials stored locally in `SharedPreferences`

### Networking
- Prefer HTTPS/WSS over HTTP/WS
- Handle timeouts gracefully (HTTP: 3s timeout)
- Reconnect logic for WebSocket and MQTT

---

## Platform-Specific Notes

### Android
- Target SDK 34, min SDK 21
- Proguard rules in `android/app/proguard-rules.pro`
- Foreground service for persistent notification
- Request BLE permissions dynamically (Android 12+ uses BLUETOOTH_SCAN/CONNECT)

### iOS / macOS
- Requires Bluetooth permission in Info.plist
- macOS: enable Bluetooth in entitlements

### Windows
- Uses `universal_ble` with native WinRT API
- C++ standard: C++20
- Known issue: Chinese paths may cause runtime failures

### Linux
- BlueZ-based BLE via `universal_ble`
- Ensure `bluez` is installed

---

## Quick Reference

| Task | Command |
|------|---------|
| Install deps | `flutter pub get` |
| Run app | `flutter run -d <device>` |
| Run tests | `flutter test` |
| Format code | `dart format .` |
| Analyze | `dart analyze` |
| Gen l10n | `flutter gen-l10n` |
| Build Android | `flutter build apk` |
| Build macOS | `flutter build macos` |
| Build Windows | `flutter build windows` |
| Create release | `git tag vX.Y.Z && git push origin vX.Y.Z` |
