/// Pure validation helpers for settings form fields.
///
/// Every validator returns `null` when the value is acceptable and an
/// error-message **key** (resolved through l10n by the caller) otherwise.
class SettingsValidator {
  SettingsValidator._();

  static const int minUpdateIntervalMs = 250;
  static const int minMaxHeartRate = 100;
  static const int maxMaxHeartRate = 250;

  /// HTTP/HTTPS/WS/WSS endpoint. Empty is allowed (push disabled).
  static String? pushEndpoint(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse(trimmed);
    if (uri == null || uri.host.isEmpty || uri.scheme.isEmpty) {
      return 'errInvalidUrl';
    }
    const schemes = ['http', 'https', 'ws', 'wss'];
    if (!schemes.contains(uri.scheme.toLowerCase())) {
      return 'errInvalidUrl';
    }
    return null;
  }

  /// OSC target as `host:port`. Empty is allowed (OSC disabled).
  static String? oscAddress(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final uri = Uri.tryParse('scheme://$trimmed');
    if (uri == null || uri.host.isEmpty || uri.port <= 0) {
      return 'errInvalidOscAddress';
    }
    if (uri.port < 1 || uri.port > 65535) return 'errInvalidOscAddress';
    return null;
  }

  /// OSC parameter path must start with '/' when non-empty.
  static String? oscPath(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;
    if (!trimmed.startsWith('/')) return 'errInvalidOscPath';
    return null;
  }

  static String? port(String value, {int fallback = 1883}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null; // falls back to default
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'errInvalidPort';
    if (parsed < 1 || parsed > 65535) return 'errInvalidPort';
    return null;
  }

  static String? updateIntervalMs(String value) {
    final trimmed = value.trim();
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'errInvalidInterval';
    if (parsed < minUpdateIntervalMs) return 'errInvalidInterval';
    if (parsed > 60000) return 'errInvalidInterval';
    return null;
  }

  static String? maxHeartRate(String value) {
    final trimmed = value.trim();
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'errInvalidMaxHr';
    if (parsed < minMaxHeartRate || parsed > maxMaxHeartRate) {
      return 'errInvalidMaxHr';
    }
    return null;
  }

  static String? heartbeatPulseDurationMs(String value) {
    final trimmed = value.trim();
    final parsed = int.tryParse(trimmed);
    if (parsed == null) return 'errInvalidPulseDuration';
    if (parsed < 20 || parsed > 1000) return 'errInvalidPulseDuration';
    return null;
  }

  /// Parse a port, returning [fallback] for empty/invalid input so callers
  /// can decide whether to surface the validation error or use the default.
  static int parsePort(String value, int fallback) {
    return int.tryParse(value.trim()) ?? fallback;
  }
}
