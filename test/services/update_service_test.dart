import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:hr_push/services/update_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _releaseJson({
  required String tag,
  Map<String, String> assets = const {},
}) {
  return jsonEncode({
    'tag_name': tag,
    'body': 'release notes for $tag',
    'html_url': 'https://github.com/Ero-Cat/hr_push/releases/tag/$tag',
    'assets': [
      for (final entry in assets.entries)
        {'name': entry.key, 'browser_download_url': entry.value},
    ],
  });
}

// Assets for every desktop platform so download tests pass regardless of
// the OS the test host runs on.
const _allDesktopAssets = {
  'hr-push-macos-v999.0.0.zip': 'https://example.com/dl/hr-push-macos.zip',
  'hr-push-linux-v999.0.0.tar.gz':
      'https://example.com/dl/hr-push-linux.tar.gz',
  'hr-push-windows-v999.0.0-setup.exe': 'https://example.com/dl/hr-push.exe',
  'hr-push-windows-v999.0.0.zip': 'https://example.com/dl/hr-push-win.zip',
};

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('compareVersions', () {
    test('orders dotted versions numerically', () {
      expect(UpdateService.compareVersions('1.8.2', '1.9.0'), lessThan(0));
      expect(UpdateService.compareVersions('1.10.0', '1.9.9'), greaterThan(0));
      expect(UpdateService.compareVersions('2.0', '2.0.0'), 0);
      expect(UpdateService.compareVersions('1.0.0', '0.99.99'), greaterThan(0));
    });

    test('tolerates v prefix, build numbers and pre-release suffixes', () {
      expect(UpdateService.compareVersions('v1.9.0', '1.9.0'), 0);
      expect(UpdateService.compareVersions('1.9.0+30', '1.9.0'), 0);
      expect(UpdateService.compareVersions('1.9.0-beta.1', '1.9.0'), 0);
    });
  });

  group('pickAssetUrl', () {
    const assets = _allDesktopAssets;

    test('android prefers the ABI-matched apk then universal', () {
      const androidAssets = {
        'app-release-v1.9.0.apk': 'https://x/universal.apk',
        'hr-push-android-v1.9.0-arm64.apk': 'https://x/arm64.apk',
        'hr-push-android-v1.9.0-arm32.apk': 'https://x/arm32.apk',
      };
      expect(
        UpdateService.pickAssetUrl(androidAssets, 'android', 'arm64'),
        'https://x/arm64.apk',
      );
      expect(
        UpdateService.pickAssetUrl(androidAssets, 'android', 'arm32'),
        'https://x/arm32.apk',
      );
      // Unknown ABI (or missing split) falls back to the universal apk.
      expect(
        UpdateService.pickAssetUrl(androidAssets, 'android', ''),
        'https://x/universal.apk',
      );
      expect(
        UpdateService.pickAssetUrl(androidAssets, 'android', 'x64'),
        'https://x/universal.apk',
      );
    });

    test('windows prefers the installer then the zip', () {
      expect(
        UpdateService.pickAssetUrl(assets, 'windows', ''),
        'https://example.com/dl/hr-push.exe',
      );
      const zipOnly = {
        'hr-push-windows-v1.9.0.zip': 'https://example.com/dl/win.zip',
      };
      expect(
        UpdateService.pickAssetUrl(zipOnly, 'windows', ''),
        'https://example.com/dl/win.zip',
      );
    });

    test('macos and linux match their own artifacts', () {
      expect(
        UpdateService.pickAssetUrl(assets, 'macos', ''),
        'https://example.com/dl/hr-push-macos.zip',
      );
      expect(
        UpdateService.pickAssetUrl(assets, 'linux', ''),
        'https://example.com/dl/hr-push-linux.tar.gz',
      );
    });
  });

  group('checkForUpdates', () {
    test('marks a newer release available', () async {
      final svc = UpdateService(
        client: MockClient(
          (request) async => http.Response(_releaseJson(tag: 'v999.0.0'), 200),
        ),
      );

      await svc.checkForUpdates(manual: true);

      expect(svc.status, UpdateStatus.available);
      expect(svc.updateAvailable, isTrue);
      expect(svc.shouldShowBanner, isTrue);
      expect(svc.latest!.version, '999.0.0');
    });

    test('reports up to date when the release is not newer', () async {
      final svc = UpdateService(
        client: MockClient(
          (request) async => http.Response(_releaseJson(tag: 'v0.0.1'), 200),
        ),
      );

      await svc.checkForUpdates(manual: true);

      expect(svc.status, UpdateStatus.upToDate);
      expect(svc.updateAvailable, isFalse);
    });

    test('flags failure on HTTP errors and bad payloads', () async {
      final httpError = UpdateService(
        client: MockClient(
          (request) async => http.Response('rate limited', 403),
        ),
      );
      await httpError.checkForUpdates(manual: true);
      expect(httpError.status, UpdateStatus.failed);

      final badJson = UpdateService(
        client: MockClient((request) async => http.Response('oops', 200)),
      );
      await badJson.checkForUpdates(manual: true);
      expect(badJson.status, UpdateStatus.failed);
    });

    test('automatic checks are throttled to once per day', () async {
      var requests = 0;
      final svc = UpdateService(
        client: MockClient((request) async {
          requests++;
          return http.Response(_releaseJson(tag: 'v999.0.0'), 200);
        }),
      );

      final now = DateTime.now().millisecondsSinceEpoch;
      SharedPreferences.setMockInitialValues({
        'last_update_check_ts': now - const Duration(minutes: 1).inMilliseconds,
      });

      await svc.checkForUpdates();
      expect(requests, 0, reason: 'recent check must short-circuit');
      expect(svc.status, UpdateStatus.idle);

      await svc.checkForUpdates(manual: true);
      expect(requests, 1, reason: 'manual checks bypass the throttle');
    });

    test(
      'skipping the version hides the banner until the next release',
      () async {
        final svc = UpdateService(
          client: MockClient(
            (request) async =>
                http.Response(_releaseJson(tag: 'v999.0.0'), 200),
          ),
        );
        await svc.checkForUpdates(manual: true);
        expect(svc.shouldShowBanner, isTrue);

        await svc.ignoreCurrentVersion();
        expect(svc.shouldShowBanner, isFalse);

        final prefs = await SharedPreferences.getInstance();
        expect(prefs.getString('skipped_update_version'), '999.0.0');

        // A later re-check for the same version keeps it hidden.
        await svc.checkForUpdates(manual: true);
        expect(svc.shouldShowBanner, isFalse);
      },
    );
  });

  group('downloadUpdate', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('hr_push_update_test');
    });

    tearDown(() async {
      await tempDir.delete(recursive: true);
    });

    test('streams the package to disk and reports progress', () async {
      final bytes = Uint8List.fromList(List.filled(1024, 7));
      final svc = UpdateService(
        client: MockClient.streaming((request, bodyStream) async {
          if (request.url.path.endsWith('/latest')) {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  _releaseJson(tag: 'v999.0.0', assets: _allDesktopAssets),
                ),
              ),
              200,
            );
          }
          return http.StreamedResponse(
            Stream.value(bytes),
            200,
            contentLength: bytes.length,
          );
        }),
        downloadDir: () async => tempDir,
      );

      await svc.checkForUpdates(manual: true);
      expect(svc.updateAvailable, isTrue);

      final done = await svc.downloadUpdate();
      expect(done, isTrue);
      expect(svc.status, UpdateStatus.downloaded);
      expect(svc.downloadProgress, 1.0);
      expect(svc.downloadedFilePath, isNotNull);

      final file = File(svc.downloadedFilePath!);
      expect(file.existsSync(), isTrue);
      expect(file.lengthSync(), bytes.length);
    });

    test('cancel removes the partial file and restores availability', () async {
      final firstChunk = Uint8List.fromList(List.filled(512, 1));
      final controller = StreamController<Uint8List>();

      var requestCount = 0;
      final svc = UpdateService(
        client: MockClient.streaming((request, bodyStream) async {
          requestCount++;
          if (requestCount == 1) {
            return http.StreamedResponse(
              Stream.value(
                utf8.encode(
                  _releaseJson(tag: 'v999.0.0', assets: _allDesktopAssets),
                ),
              ),
              200,
            );
          }
          return http.StreamedResponse(
            controller.stream,
            200,
            contentLength: 1024,
          );
        }),
        downloadDir: () async => tempDir,
      );

      await svc.checkForUpdates(manual: true);
      expect(svc.updateAvailable, isTrue);

      final download = svc.downloadUpdate();
      await Future<void>.delayed(Duration.zero);
      controller.add(firstChunk);
      await Future<void>.delayed(Duration.zero);
      expect(svc.status, UpdateStatus.downloading);

      svc.cancelDownload();
      controller.add(firstChunk);
      final done = await download;
      expect(done, isFalse);
      expect(svc.status, UpdateStatus.available);
      expect(
        Directory(tempDir.path).listSync().whereType<File>().toList(),
        isEmpty,
        reason: 'cancelled downloads must not leave partial files',
      );
      await controller.close();
    });
  });
}
