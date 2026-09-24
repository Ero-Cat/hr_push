import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:web_socket_channel/io.dart';

import '../app_log.dart';

/// HTTP/WebSocket Service for pushing heart rate data
class HttpWsService {
  HttpWsService({required this.endpoint, this.onLog});

  final String endpoint;
  final void Function(String message, {Object? error})? onLog;

  // A single client with a keep-alive connection pool: HR pushes arrive
  // ~1/s and a fresh client per request would redo TCP+TLS every time.
  http.Client? _httpClient;

  IOWebSocketChannel? _wsChannel;
  bool _wsConnecting = false;
  StreamSubscription? _wsSub;
  int _wsFailures = 0;
  DateTime? _wsRetryAfter;

  bool get isEnabled => endpoint.trim().isNotEmpty;

  Uri? get _uri => Uri.tryParse(endpoint.trim());

  void _log(String message, {Object? error}) {
    onLog?.call(message, error: error);
    AppLog.info(message);
  }

  String _formatEndpoint(Uri uri) {
    return '${uri.host}:${uri.port}${uri.path}';
  }

  /// Send payload via HTTP or WebSocket based on endpoint scheme
  Future<void> send(Map<String, dynamic> payload) async {
    final uri = _uri;
    if (uri == null) return;

    if (uri.scheme.startsWith('ws')) {
      _log('push ws start: ${_formatEndpoint(uri)}');
      await _sendWs(uri, payload);
    } else if (uri.scheme.startsWith('http')) {
      _log('push http start: ${_formatEndpoint(uri)}');
      await _sendHttp(uri, payload);
    }
  }

  Future<void> _sendHttp(Uri uri, Map<String, dynamic> payload) async {
    _httpClient ??= IOClient();
    try {
      final response = await _httpClient!
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));
      _log('push http ${response.statusCode}: ${_formatEndpoint(uri)}');
    } catch (e) {
      _log('push http failed: ${_formatEndpoint(uri)}', error: e);
    }
  }

  Future<void> _sendWs(Uri uri, Map<String, dynamic> payload) async {
    final channel = _wsChannel;
    if (channel != null && channel.closeCode == null) {
      _trySink(channel, payload, uri);
      return;
    }

    if (_wsConnecting) return;
    // Exponential reconnect backoff (1/2/4/... capped at 30s) so a dead
    // endpoint is not hammered on every heart-rate tick.
    final retryAfter = _wsRetryAfter;
    if (retryAfter != null && DateTime.now().isBefore(retryAfter)) {
      _log('push ws waiting to reconnect: ${_formatEndpoint(uri)}');
      return;
    }

    await _connectWs(uri);
    final fresh = _wsChannel;
    if (fresh != null) {
      _trySink(fresh, payload, uri);
    }
  }

  void _trySink(
    IOWebSocketChannel channel,
    Map<String, dynamic> payload,
    Uri uri,
  ) {
    try {
      channel.sink.add(jsonEncode(payload));
      _log('push ws sent: ${_formatEndpoint(uri)}');
    } catch (_) {}
  }

  Future<void> _connectWs(Uri uri) async {
    _wsConnecting = true;
    try {
      final channel = IOWebSocketChannel.connect(
        uri,
        pingInterval: const Duration(seconds: 10),
      );
      await channel.ready.timeout(const Duration(seconds: 5));
      _wsSub?.cancel();
      _wsSub = channel.stream.listen(
        (_) {},
        onError: (Object e) {
          _log('push ws error: ${_formatEndpoint(uri)}', error: e);
          _onWsDown();
        },
        onDone: () {
          _log('push ws closed: ${_formatEndpoint(uri)}');
          _onWsDown();
        },
      );
      _wsChannel = channel;
      _wsFailures = 0;
      _wsRetryAfter = null;
      _log('push ws connected: ${_formatEndpoint(uri)}');
    } catch (e) {
      _log('push ws connect failed: ${_formatEndpoint(uri)}', error: e);
      _onWsDown();
    } finally {
      _wsConnecting = false;
    }
  }

  void _onWsDown() {
    _wsChannel = null;
    _wsFailures++;
    final delaySeconds = backoffSecondsFor(_wsFailures);
    _wsRetryAfter = DateTime.now().add(Duration(seconds: delaySeconds));
  }

  @visibleForTesting
  static int backoffSecondsFor(int failures) {
    if (failures <= 0) return 0;
    return (1 << (failures - 1)).clamp(1, 30);
  }

  void dispose() {
    _wsSub?.cancel();
    _wsChannel?.sink.close();
    _wsChannel = null;
    _httpClient?.close();
    _httpClient = null;
  }
}
