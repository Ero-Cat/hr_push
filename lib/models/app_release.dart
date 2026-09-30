import 'dart:convert';

/// Metadata of a GitHub release, parsed from the payload of
/// `GET /repos/{owner}/{repo}/releases/latest`.
class AppRelease {
  const AppRelease({
    required this.tagName,
    required this.version,
    required this.notes,
    required this.pageUrl,
    required this.assetUrls,
    this.publishedAt,
  });

  /// Release tag, e.g. `v1.9.0`.
  final String tagName;

  /// Tag without the leading `v`, e.g. `1.9.0` (matches `appVersion`).
  final String version;

  /// Release notes (markdown) as published on GitHub.
  final String notes;

  /// Web page of the release, used as the manual-download fallback.
  final String pageUrl;

  /// Download URLs keyed by lowercased asset file name.
  final Map<String, String> assetUrls;

  final DateTime? publishedAt;

  /// Parse the JSON body of a GitHub `releases/latest` response.
  /// Returns `null` when the payload is not a usable release.
  static AppRelease? fromGithubJson(String body) {
    try {
      final json = jsonDecode(body);
      if (json is! Map<String, dynamic>) return null;
      final tagName = json['tag_name'];
      if (tagName is! String || tagName.isEmpty) return null;

      final assets = <String, String>{};
      final rawAssets = json['assets'];
      if (rawAssets is List) {
        for (final asset in rawAssets) {
          if (asset is Map<String, dynamic>) {
            final name = asset['name'];
            final url = asset['browser_download_url'];
            if (name is String && url is String && url.isNotEmpty) {
              assets[name.toLowerCase()] = url;
            }
          }
        }
      }

      final publishedRaw = json['published_at'];
      return AppRelease(
        tagName: tagName,
        version: stripTagPrefix(tagName),
        notes: (json['body'] as String? ?? '').trim(),
        pageUrl: (json['html_url'] as String? ?? '').trim(),
        assetUrls: assets,
        publishedAt: publishedRaw is String
            ? DateTime.tryParse(publishedRaw)
            : null,
      );
    } catch (_) {
      return null;
    }
  }

  /// `v1.9.0` → `1.9.0`; tags without the prefix pass through unchanged.
  static String stripTagPrefix(String tag) =>
      tag.startsWith('v') ? tag.substring(1) : tag;

  /// Notes as readable plain text: strips common markdown decorations so the
  /// update dialog stays free of a markdown dependency.
  String get plainNotes => markdownToPlain(notes);

  static String markdownToPlain(String markdown) {
    final lines = <String>[];
    for (var line in markdown.split('\n')) {
      line = line.trim();
      if (line.isEmpty) {
        if (lines.isNotEmpty && lines.last.isNotEmpty) lines.add('');
        continue;
      }
      // Skip GitHub's "Full Changelog" compare links.
      if (line.startsWith('**Full Changelog**')) continue;
      if (line.startsWith('[') && line.contains('](https://github.com/')) {
        continue;
      }
      if (line.startsWith('https://github.com/') &&
          line.endsWith('/compare/')) {
        continue;
      }
      line = line
          .replaceAllMapped(
            RegExp(r'\[([^\]]+)\]\([^)]*\)'),
            (m) => m.group(1)!,
          )
          .replaceAll(RegExp(r'!\[[^\]]*\]\([^)]*\)'), '')
          .replaceAll(RegExp(r'^#{1,6}\s*'), '')
          .replaceAll(RegExp(r'^[-*+]\s+'), '• ')
          // replaceAll has no back-references, so emphasis/backtick pairs
          // need replaceAllMapped.
          .replaceAllMapped(
            RegExp(r'\*{1,3}([^*]+)\*{1,3}'),
            (m) => m.group(1)!,
          )
          .replaceAllMapped(
            RegExp(r'`{1,3}([^`]*)`{1,3}'),
            (m) => m.group(1) ?? '',
          );
      lines.add(line);
    }
    while (lines.isNotEmpty && lines.last.isEmpty) {
      lines.removeLast();
    }
    return lines.join('\n');
  }
}
