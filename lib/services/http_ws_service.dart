import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

import '../app_log.dart';

/// HTTP/WebSocket Service for pushing heart rate data
class HttpWsService {
  HttpWsService({
    required this.endpoint,
    this.onLog,
  });

  final String endpoint;
  final void Function(String message, {Object? error})? onLog;

  IOWebSocketChannel? _wsChannel;
  bool _wsConnecting = false;

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
    try {
      await http
          .post(
            uri,
            headers: {'content-type': 'application/json'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 3));
      _log('push http ok: ${_formatEndpoint(uri)}');
    } catch (e) {
      _log('push http failed: ${_formatEndpoint(uri)}', error: e);
    }
  }

  Future<void> _sendWs(Uri uri, Map<String, dynamic> payload) async {
    if (_wsChannel == null || _wsChannel!.closeCode != null) {
      if (_wsConnecting) return;
      _wsConnecting = true;
      try {
        _wsChannel = IOWebSocketChannel.connect(
          uri,
          pingInterval: const Duration(seconds: 10),
        );
        _wsChannel!.stream.listen(
          (_) {},
          onError: (_) {
            _log('push ws error: ${_formatEndpoint(uri)}');
            _wsChannel = null;
          },
          onDone: () {
            _log('push ws closed: ${_formatEndpoint(uri)}');
            _wsChannel = null;
          },
        );
        _log('push ws connected: ${_formatEndpoint(uri)}');
      } catch (e) {
        _log('push ws connect failed: ${_formatEndpoint(uri)}', error: e);
        _wsChannel = null;
      } finally {
        _wsConnecting = false;
      }
    }

    if (_wsChannel != null) {
      try {
        _wsChannel!.sink.add(jsonEncode(payload));
        _log('push ws sent: ${_formatEndpoint(uri)}');
      } catch (_) {}
    }
  }

  void dispose() {
    _wsChannel?.sink.close();
    _wsChannel = null;
  }
}
