import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:hr_push/models/app_release.dart';

void main() {
  group('AppRelease.fromGithubJson', () {
    test('parses tag, notes, page url and asset download urls', () {
      final payload = jsonEncode({
        'tag_name': 'v1.9.0',
        'body': '## What is Changed\n- Fix BLE reconnect',
        'html_url': 'https://github.com/Ero-Cat/hr_push/releases/tag/v1.9.0',
        'published_at': '2026-09-01T00:00:00Z',
        'assets': [
          {
            'name': 'app-release-v1.9.0.apk',
            'browser_download_url':
                'https://example.com/app-release-v1.9.0.apk',
          },
          {
            'name': 'hr-push-android-v1.9.0-arm64.apk',
            'browser_download_url':
                'https://example.com/hr-push-android-v1.9.0-arm64.apk',
          },
          {'name': 'source.zip', 'browser_download_url': ''},
        ],
      });

      final release = AppRelease.fromGithubJson(payload)!;

      expect(release.tagName, 'v1.9.0');
      expect(release.version, '1.9.0');
      expect(release.notes, contains('Fix BLE reconnect'));
      expect(release.pageUrl, contains('releases/tag/v1.9.0'));
      expect(release.publishedAt, isNotNull);
      // Empty download URLs are dropped; names are lowercased keys.
      expect(release.assetUrls.length, 2);
      expect(
        release.assetUrls['hr-push-android-v1.9.0-arm64.apk'],
        contains('arm64'),
      );
    });

    test('returns null for payloads without a usable tag', () {
      expect(AppRelease.fromGithubJson('{"message":"Not Found"}'), isNull);
      expect(AppRelease.fromGithubJson('not json at all'), isNull);
      expect(AppRelease.fromGithubJson('[]'), isNull);
    });
  });

  group('AppRelease.markdownToPlain', () {
    test('strips headings, bullets, links and emphasis', () {
      const markdown = '''
## What's Changed
* **New** support for `MQTT 5`
- See the [release notes](https://github.com/x) for details.

**Full Changelog**: https://github.com/Ero-Cat/hr_push/compare/v1.8.2...v1.9.0
''';

      final plain = AppRelease.markdownToPlain(markdown);

      expect(plain, contains('• New support for MQTT 5'));
      expect(plain, contains('See the release notes for details.'));
      expect(plain, isNot(contains('[')));
      expect(plain, isNot(contains('Full Changelog')));
      expect(plain, isNot(contains('#')));
    });
  });
}
