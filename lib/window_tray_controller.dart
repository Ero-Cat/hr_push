import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/widgets.dart';
import 'package:provider/provider.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'heart_rate_manager.dart';

/// App-shell integration wrapper:
///
/// - Windows system tray: closing the window hides it to the tray (background
///   monitoring keeps running); the tray icon restores or quits.
/// - UI visibility gate on every desktop platform: minimizing or hiding the
///   window pauses animations and UI notifications via
///   [HeartRateManager.setUiVisible] (mobile lifecycle is covered by the
///   [WidgetsBindingObserver] registered here as well).
class WindowTrayController extends StatefulWidget {
  const WindowTrayController({super.key, required this.child});

  final Widget child;

  @override
  State<WindowTrayController> createState() => _WindowTrayControllerState();
}

class _WindowTrayControllerState extends State<WindowTrayController>
    with WindowListener, TrayListener, WidgetsBindingObserver {
  static const _menuShow = 'tray_show';
  static const _menuQuit = 'tray_quit';

  /// Tray icon + hide-to-tray on close: Windows only.
  bool get _trayEnabled => !kIsWeb && Platform.isWindows;

  /// Window visibility events: every desktop platform (minimize/restore,
  /// hide/show). Mobile relies on the lifecycle observer instead.
  bool get _windowEventsEnabled =>
      !kIsWeb && (Platform.isWindows || Platform.isMacOS || Platform.isLinux);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (_windowEventsEnabled) {
      windowManager.addListener(this);
    }
    if (_trayEnabled) {
      trayManager.addListener(this);
      _init();
    }
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

  void _setUiVisible(bool visible) {
    if (!mounted) return;
    context.read<HeartRateManager>().setUiVisible(visible);
  }

  // Desktop: minimizing stops rendering work, restoring resumes it. (The
  // hide-to-tray path has no WindowListener event in window_manager 0.5.x,
  // so onWindowClose/tray-restore set visibility directly.) The manager's
  // setter is idempotent, so duplicated events (window_manager + lifecycle)
  // are harmless.
  @override
  void onWindowMinimize() => _setUiVisible(false);

  @override
  void onWindowRestore() => _setUiVisible(true);

  // Mobile (and desktop platforms that report lifecycle instead of window
  // events): only fully-invisible states pause the UI; `inactive` can be a
  // transient overlay (notification shade, app switcher) with the window
  // still on screen, so it keeps animating.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _setUiVisible(false);
      case AppLifecycleState.resumed:
        _setUiVisible(true);
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  void onWindowClose() async {
    // Hide to tray instead of exiting so BLE monitoring keeps running.
    // No window event fires for hide() in window_manager 0.5.x, so pause
    // the UI work explicitly here.
    await windowManager.hide();
    _setUiVisible(false);
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
    _setUiVisible(true);
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
        _setUiVisible(true);
      case _menuQuit:
        await windowManager.setPreventClose(false);
        await windowManager.destroy();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_windowEventsEnabled) {
      windowManager.removeListener(this);
    }
    if (_trayEnabled) {
      trayManager.removeListener(this);
      trayManager.destroy();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
