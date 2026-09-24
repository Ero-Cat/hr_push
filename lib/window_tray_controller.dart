import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

/// Windows system-tray integration: closing the window hides it to the tray
/// (background monitoring keeps running); the tray icon restores or quits.
class WindowTrayController extends StatefulWidget {
  const WindowTrayController({super.key, required this.child});

  final Widget child;

  @override
  State<WindowTrayController> createState() => _WindowTrayControllerState();
}

class _WindowTrayControllerState extends State<WindowTrayController>
    with WindowListener, TrayListener {
  static const _menuShow = 'tray_show';
  static const _menuQuit = 'tray_quit';

  bool get _enabled => !kIsWeb && Platform.isWindows;

  @override
  void initState() {
    super.initState();
    if (!_enabled) return;
    windowManager.addListener(this);
    trayManager.addListener(this);
    _init();
  }

  Future<void> _init() async {
    try {
      await windowManager.setPreventClose(true);
      await trayManager.setIcon('images/logo.ico');
      await trayManager.setToolTip('HR PUSH');
      await trayManager.setContextMenu(
        Menu(
          items: [
            MenuItem(key: _menuShow, label: 'Show HR PUSH'),
            MenuItem.separator(),
            MenuItem(key: _menuQuit, label: 'Exit'),
          ],
        ),
      );
    } catch (_) {
      // Tray unavailable (e.g. unusual Windows session); the close button
      // then behaves normally.
      await windowManager.setPreventClose(false);
    }
  }

  @override
  void onWindowClose() async {
    // Hide to tray instead of exiting so BLE monitoring keeps running.
    await windowManager.hide();
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }

  @override
  void onTrayIconRightMouseDown() {
    // Windows fires this callback on right-click and does NOT pop the menu
    // natively (tray_manager windows/tray_manager_plugin.cpp WM_RBUTTONUP);
    // without this call there is no way to reach the Exit item.
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayIconRightMouseUp() {
    // macOS/other platforms deliver right-click on mouse-up.
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) async {
    switch (menuItem.key) {
      case _menuShow:
        await windowManager.show();
        await windowManager.focus();
      case _menuQuit:
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
    }
  }

  @override
  void dispose() {
    if (_enabled) {
      windowManager.removeListener(this);
      trayManager.removeListener(this);
      trayManager.destroy();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
