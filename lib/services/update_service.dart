import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../app_log.dart';
import '../app_metadata.dart';
import '../models/app_release.dart';

enum UpdateStatus {
  idle,
  checking,
  upToDate,
  available,
  downloading,
  downloaded,
  failed,
}

/// Checks GitHub Releases for a newer version and drives the per-platform
/// download/install flow. Kept separate from [HeartRateManager] so update
/// traffic never interferes with BLE or push connections.
class UpdateService extends ChangeNotifier {
  UpdateService({
    http.Client? client,
    Future<Directory> Function()? downloadDir,
  }) : _client = client ?? http.Client(),
       _downloadDir = downloadDir ?? _defaultDownloadDir;

  static const _ownerRepo = 'Ero-Cat/hr_push';
  static const _latestUrl =
      'https://api.github.com/repos/$_ownerRepo/releases/latest';
  static const _releasePageUrl =
      'https://github.com/$_ownerRepo/releases/latest';
  static const _timeout = Duration(seconds: 8);
  static const _autoCheckInterval = Duration(hours: 24);
  static const _prefsLastCheck = 'last_update_check_ts';
  static const _prefsSkippedVersion = 'skipped_update_version';
  static const _abiChannel = MethodChannel('moe.iacg.hrpush/system');

  /// Google Play builds pass `--dart-define=PLAY_BUILD=true`: Play policy
  /// forbids self-updating apps, so the whole updater compiles out there.
  /// Users on Play update through the store.
  static const playBuild = bool.fromEnvironment(
    'PLAY_BUILD',
    defaultValue: false,
  );

  final http.Client _client;
  final Future<Directory> Function() _downloadDir;

  UpdateStatus status = UpdateStatus.idle;
  AppRelease? latest;

  /// Failure detail of the last check/download, shown by manual checks.
  String? error;
  double downloadProgress = 0;
  String? downloadedFilePath;

  /// True when the user chose to hide the banner for [AppRelease.version].
  bool skippedCurrentVersion = false;
  bool _cancelRequested = false;
  String? _androidAbi;

  /// Whether a release newer than the running app is known.
  bool get updateAvailable =>
      latest != null && compareVersions(appVersion, latest!.version) < 0;

  /// Whether the dashboard banner should be visible.
  bool get shouldShowBanner =>
      updateAvailable &&
      !skippedCurrentVersion &&
      status != UpdateStatus.checking;

  /// Compare dotted versions like `1.8.2` / `v1.9.0` / `2.0.0+30`.
  /// Build numbers and pre-release suffixes are ignored; shorter versions
  /// compare as if padded with zeros. Returns <0, 0 or >0.
  @visibleForTesting
  static int compareVersions(String a, String b) {
    List<int> parse(String version) {
      var v = version.trim().toLowerCase();
      if (v.startsWith('v')) v = v.substring(1);
      v = v.split('+').first.split('-').first;
      return v.split('.').map((part) => int.tryParse(part) ?? 0).toList();
    }

    final pa = parse(a);
    final pb = parse(b);
    final length = pa.length > pb.length ? pa.length : pb.length;
    for (var i = 0; i < length; i++) {
      final x = i < pa.length ? pa[i] : 0;
      final y = i < pb.length ? pb[i] : 0;
      if (x != y) return x.compareTo(y);
    }
    return 0;
  }

  /// Pick the download URL for [platform] ('android'/'windows'/'macos'/
  /// 'linux'/'ios') from the release assets, matching the CI naming scheme
  /// (`app-release-vX.apk`, `hr-push-android-vX-arm64.apk`,
  /// `hr-push-windows-vX-setup.exe`, `hr-push-macos-vX.zip`, …).
  /// [abi] is the Android primary ABI ('arm64'/'arm32'/'x64').
  @visibleForTesting
  static String? pickAssetUrl(
    Map<String, String> assets,
    String platform,
    String abi,
  ) {
    String? find(bool Function(String name) test) {
      for (final entry in assets.entries) {
        if (test(entry.key)) return entry.value;
      }
      return null;
    }

    switch (platform) {
      case 'android':
        if (abi == 'arm64') {
          final url = find((n) => n.endsWith('-arm64.apk'));
          if (url != null) return url;
        } else if (abi == 'arm32') {
          final url = find((n) => n.endsWith('-arm32.apk'));
          if (url != null) return url;
        }
        return find(
              (n) => n.startsWith('app-release-') && n.endsWith('.apk'),
            ) ??
            find((n) => n.endsWith('.apk'));
      case 'windows':
        return find((n) => n.endsWith('-setup.exe')) ??
            find((n) => n.startsWith('hr-push-windows-') && n.endsWith('.zip'));
      case 'macos':
        return find(
          (n) => n.startsWith('hr-push-macos-') && n.endsWith('.zip'),
        );
      case 'linux':
        return find(
          (n) => n.startsWith('hr-push-linux-') && n.endsWith('.tar.gz'),
        );
    }
    return null;
  }

  /// Check GitHub for a newer release. Automatic checks are throttled to one
  /// per [_autoCheckInterval]; [manual] checks always run and surface errors.
  Future<void> checkForUpdates({bool manual = false}) async {
    if (playBuild) return;
    if (status == UpdateStatus.checking || status == UpdateStatus.downloading) {
      return;
    }
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!manual) {
        final lastCheck = prefs.getInt(_prefsLastCheck) ?? 0;
        final elapsed = DateTime.now().millisecondsSinceEpoch - lastCheck;
        if (elapsed < _autoCheckInterval.inMilliseconds) return;
      }
      await prefs.setInt(
        _prefsLastCheck,
        DateTime.now().millisecondsSinceEpoch,
      );
    } catch (e) {
      // Prefs failing must not block the check itself.
      _log('read update prefs failed', error: e);
    }

    status = UpdateStatus.checking;
    error = null;
    notifyListeners();

    try {
      final response = await _client
          .get(
            Uri.parse(_latestUrl),
            headers: {
              'user-agent': 'hr_push/$appVersion',
              'accept': 'application/vnd.github+json',
            },
          )
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final release = AppRelease.fromGithubJson(response.body);
      if (release == null) {
        throw Exception('invalid release payload');
      }

      final prefs = await SharedPreferences.getInstance();
      skippedCurrentVersion =
          prefs.getString(_prefsSkippedVersion) == release.version;
      downloadedFilePath = null;
      downloadProgress = 0;
      latest = release;
      status = updateAvailable ? UpdateStatus.available : UpdateStatus.upToDate;
      if (updateAvailable) {
        _log('update available: ${release.tagName}');
      }
    } catch (e) {
      error = e.toString();
      _log('update check failed', error: e);
      // Keep a previously found update visible; only flag failure when the
      // banner would otherwise show nothing.
      status = updateAvailable ? UpdateStatus.available : UpdateStatus.failed;
    }
    notifyListeners();
  }

  /// Hide the banner for the currently known newer version.
  Future<void> ignoreCurrentVersion() async {
    final release = latest;
    if (release == null || !updateAvailable) return;
    skippedCurrentVersion = true;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefsSkippedVersion, release.version);
    } catch (e) {
      _log('persist skipped version failed', error: e);
    }
  }

  /// Download the update package for this platform, reporting progress via
  /// [downloadProgress]. Returns whether the file is ready to install.
  Future<bool> downloadUpdate() async {
    final release = latest;
    if (release == null || status == UpdateStatus.downloading) return false;

    final abi = Platform.isAndroid ? await _detectAndroidAbi() : '';
    final url = pickAssetUrl(release.assetUrls, Platform.operatingSystem, abi);
    if (url == null) {
      error = 'no matching release asset for this platform';
      _log(error!);
      status = UpdateStatus.available;
      notifyListeners();
      return false;
    }

    _cancelRequested = false;
    downloadedFilePath = null;
    downloadProgress = 0;
    status = UpdateStatus.downloading;
    notifyListeners();

    final fileName = url.split('/').last;
    File? file;
    try {
      final response = await _client
          .send(http.Request('GET', Uri.parse(url)))
          .timeout(_timeout);
      if (response.statusCode != 200) {
        throw Exception('HTTP ${response.statusCode}');
      }
      final total = response.contentLength ?? 0;
      final dir = await _downloadDir();
      file = File('${dir.path}${Platform.pathSeparator}$fileName');
      final sink = file.openWrite();
      var received = 0;
      try {
        await for (final chunk in response.stream) {
          if (_cancelRequested) {
            throw const UpdateCancelledException();
          }
          sink.add(chunk);
          received += chunk.length;
          if (total > 0) {
            final progress = (received / total).clamp(0.0, 1.0);
            if (progress - downloadProgress >= 0.01 || progress >= 1) {
              downloadProgress = progress;
              notifyListeners();
            }
          }
        }
      } finally {
        await sink.flush();
        await sink.close();
      }
      if (_cancelRequested) {
        throw const UpdateCancelledException();
      }

      downloadedFilePath = file.path;
      status = UpdateStatus.downloaded;
      _log('update downloaded to ${file.path}');
      notifyListeners();
      return true;
    } catch (e) {
      await _cleanupPartialDownload(file);
      if (e is UpdateCancelledException) {
        downloadProgress = 0;
        status = UpdateStatus.available;
        _log('update download cancelled');
      } else {
        error = e.toString();
        _log('update download failed', error: e);
        status = UpdateStatus.available;
      }
      notifyListeners();
      return false;
    }
  }

  /// Abort an in-flight [downloadUpdate]; partial files are removed.
  void cancelDownload() {
    if (status == UpdateStatus.downloading) {
      _cancelRequested = true;
    }
  }

  /// Hand the downloaded package to the platform:
  /// - Android: opens the APK with the system package installer.
  /// - Windows (setup.exe): launches the installer and exits so Inno Setup
  ///   can replace the running files.
  /// - macOS/Linux/zip fallback: opens the file or its folder so the user
  ///   can finish the replace step manually.
  Future<bool> installUpdate() async {
    final path = downloadedFilePath;
    if (path == null) return false;

    if (Platform.isWindows && path.toLowerCase().endsWith('.exe')) {
      try {
        _log('launching installer $path');
        await Process.start(path, const [], mode: ProcessStartMode.detached);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        exit(0);
      } catch (e) {
        error = e.toString();
        _log('launch installer failed', error: e);
        notifyListeners();
        return false;
      }
    }

    try {
      final result = await OpenFilex.open(path);
      if (result.type != ResultType.done) {
        throw Exception(result.message);
      }
      _log('opened update package $path');
      return true;
    } catch (e) {
      _log('open update package failed', error: e);
      // Desktop sandboxes (e.g. macOS App Sandbox) may block spawning file
      // openers; the release page is always reachable.
      return openReleasePage();
    }
  }

  /// Open the release page in the browser (manual download fallback).
  Future<bool> openReleasePage() async {
    final target = (latest?.pageUrl.isNotEmpty ?? false)
        ? latest!.pageUrl
        : _releasePageUrl;
    try {
      return await launchUrl(
        Uri.parse(target),
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _log('open release page failed', error: e);
      return false;
    }
  }

  /// 'arm64' | 'arm32' | 'x64' | '' when unknown.
  Future<String> _detectAndroidAbi() async {
    if (_androidAbi != null) return _androidAbi!;
    try {
      final raw = await _abiChannel.invokeMethod<String>('getPrimaryAbi');
      _androidAbi = switch (raw) {
        'arm64-v8a' => 'arm64',
        'armeabi-v7a' => 'arm32',
        'x86_64' => 'x64',
        _ => '',
      };
    } catch (e) {
      // Fall back to the universal APK asset.
      _log('detect abi failed', error: e);
      _androidAbi = '';
    }
    return _androidAbi!;
  }

  static Future<Directory> _defaultDownloadDir() async {
    if (Platform.isAndroid) {
      // Served by open_filex's FileProvider (cache-path) for the installer.
      return getTemporaryDirectory();
    }
    try {
      final dir = await getDownloadsDirectory();
      if (dir != null) return dir;
    } catch (_) {
      // Some Linux setups lack XDG downloads; fall through to temp.
    }
    return getTemporaryDirectory();
  }

  Future<void> _cleanupPartialDownload(File? file) async {
    if (file == null) return;
    try {
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }

  void _log(String message, {Object? error, StackTrace? stackTrace}) {
    AppLog.info('update: $message', error: error, stackTrace: stackTrace);
  }

  @override
  void dispose() {
    _client.close();
    super.dispose();
  }
}

/// Thrown internally when the user cancels a download.
class UpdateCancelledException implements Exception {
  const UpdateCancelledException();

  @override
  String toString() => 'download cancelled';
}
