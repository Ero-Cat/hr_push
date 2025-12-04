# Repository Guidelines

## Project Structure & Module Organization
- `lib/` — main Flutter sources: UI in `main.dart`, BLE/OSC logic in `heart_rate_manager.dart`.
- `android/`, `ios/`, `macos/`, `linux/`, `windows/` — platform shells and plugin registrants.
- `test/` — widget/unit tests (default scaffold present).
- `pubspec.yaml` — dependencies, Flutter assets/config; `pubspec.lock` is committed.
- `README.md` — high-level usage and platform notes.

## Build, Test, and Development Commands
- `flutter pub get` — install dependencies.
- `flutter run -d <device>` — run the app on a target emulator/device.
- `flutter test` — run Dart/Flutter tests.
- `flutter build apk|ios|macos|windows` — produce release artifacts for the chosen platform.

## Coding Style & Naming Conventions
- Dart code: 2-space indentation; prefer `final` over `var` when possible.
- Format with `dart format .`; follow `flutter_lints` from `analysis_options.yaml`.
- Keep UI constants and colors near usage; add comments only for non-obvious logic.
- Filenames lowercase_with_underscores; classes in UpperCamelCase; methods/fields in lowerCamelCase.

## Testing Guidelines
- Use `flutter test` for unit/widget coverage; place tests under `test/` mirroring `lib/` paths.
- Name tests descriptively, e.g., `heart_rate_manager_test.dart`.
- Add minimal mocks/fakes for platform plugins where needed; avoid network in unit tests.

## Commit & Pull Request Guidelines
- Commit messages: short imperative summary (e.g., “Add OSC push throttling”).
- Pull requests should include: purpose/changes, testing performed (`flutter test`/manual run), and screenshots if UI is affected.
- Keep diffs focused; avoid unrelated formatting churn.

## Security & Configuration Tips
- Do not commit secrets; push/OSC endpoints are user-configurable in-app and should not be hardcoded.
- When adding networking, prefer HTTPS/WSS; handle failures silently to avoid UI blocking.
