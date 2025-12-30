# Linux Development Setup for Heart Rate Push

## Prerequisites

To build and run this Flutter application on Linux, you need to install the following dependencies.

### Ubuntu/Debian

```bash
sudo apt-get update
sudo apt-get install -y clang cmake ninja-build pkg-config libgtk-3-dev liblzma-dev libstdc++-12-dev
```

### Bluetooth Support (`universal_ble`)

The application uses `universal_ble` which relies on BlueZ.

```bash
sudo apt-get install -y bluez libbluetooth-dev
```

**Note:** You might need to run the application with appropriate permissions or configure udev rules to access Bluetooth devices without sudo.

### VS Code Configuration

Ensure you have the Flutter extension installed in VS Code.

## Running the App

```bash
flutter pub get
flutter run -d linux
```

## Troubleshooting

- **Bluetooth permissions:** If you cannot scan for devices, try checking `systemctl status bluetooth`.
- **Window size:** The app is designed to run in a phone-like aspect ratio (430x800) using `window_manager`.
