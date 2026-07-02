import 'dart:io';
import 'dart:typed_data';
import 'dart:convert';

import '../app_log.dart';

/// OSC argument type
class OscArg {
  final String tag;
  final List<int> data;
  OscArg(this.tag, this.data);
}

/// OSC target address
class OscTarget {
  final InternetAddress address;
  final int port;
  OscTarget(this.address, this.port);
}

/// OSC Service for sending OSC messages over UDP
/// Used primarily for VRChat avatar parameter updates
class OscService {
  OscService({
    required this.oscAddress,
    required this.hrConnectedPath,
    required this.hrValuePath,
    required this.hrPercentPath,
    required this.chatboxEnabled,
    required this.chatboxTemplate,
    this.onLog,
  });

  final String oscAddress;
  final String hrConnectedPath;
  final String hrValuePath;
  final String hrPercentPath;
  final bool chatboxEnabled;
  final String chatboxTemplate;
  final void Function(String message, {Object? error})? onLog;

  RawDatagramSocket? _socket;
  String? _lastHrConnectedKey;
  DateTime? _lastChatboxSentAt;
  String? _lastChatboxMessage;

  static const Duration _chatboxMinInterval = Duration(seconds: 2);

  bool get isEnabled => oscAddress.trim().isNotEmpty;

  void _log(String message, {Object? error}) {
    onLog?.call(message, error: error);
    AppLog.info(message);
  }

  /// Send connection status
  Future<void> sendConnectedStatus(bool connected, {bool force = false}) async {
    final key = '${oscAddress.trim()}|$hrConnectedPath|$connected';
    if (!force && _lastHrConnectedKey == key) return;

    final ok = await _sendMessage(hrConnectedPath, connected);
    if (ok) {
      _lastHrConnectedKey = key;
    }
  }

  /// Send heart rate value and percent
  Future<void> sendHeartRate(int bpm, double? percent) async {
    await _sendMessage(hrValuePath, bpm);
    if (percent != null) {
      await _sendMessage(hrPercentPath, percent);
    }
  }

  /// Send chatbox message if enabled
  Future<void> sendChatbox(int bpm, double? percent) async {
    if (!chatboxEnabled) return;

    final text = _buildChatboxText(bpm, percent);
    if (text.trim().isEmpty) return;
    if (text == _lastChatboxMessage) return;

    final now = DateTime.now();
    if (_lastChatboxSentAt != null &&
        now.difference(_lastChatboxSentAt!) < _chatboxMinInterval) {
      return;
    }

    final ok = await _sendMessageWithArgs('/chatbox/input', [
      text,
      true, // send immediately
      false, // disable notification SFX
    ]);
    if (ok) {
      _lastChatboxSentAt = now;
      _lastChatboxMessage = text;
    }
  }

  String _buildChatboxText(int bpm, double? percent) {
    final template = chatboxTemplate.trim();
    if (template.isEmpty) return '';

    final percentValue = percent == null ? null : (percent * 100).round();
    var text = template
        .replaceAll('{hr}', bpm.toString())
        .replaceAll('{percent}', percentValue?.toString() ?? '');

    text = text.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    final lines = text.split('\n');
    if (lines.length > 9) {
      text = lines.take(9).join('\n');
    }
    if (text.length > 144) {
      text = text.substring(0, 144);
    }

    return text;
  }

  Future<bool> _sendMessage(String address, Object value) async {
    final target = await _resolveTarget();
    if (target == null) {
      _log('osc target invalid: $address');
      return false;
    }
    final socket = await _ensureSocket();
    if (socket == null) {
      _log('osc socket unavailable: $address');
      return false;
    }

    final msg = _encodeMessage(address, [_argFromValue(value)]);
    try {
      socket.send(msg, target.address, target.port);
      _log('osc sent: $address -> ${target.address.address}:${target.port}');
      return true;
    } catch (_) {}
    _log('osc failed: $address -> ${target.address.address}:${target.port}');
    return false;
  }

  Future<bool> _sendMessageWithArgs(String address, List<Object> args) async {
    final target = await _resolveTarget();
    if (target == null) {
      _log('osc target invalid: $address');
      return false;
    }
    final socket = await _ensureSocket();
    if (socket == null) {
      _log('osc socket unavailable: $address');
      return false;
    }

    final oscArgs = args.map(_argFromValue).toList();
    final msg = _encodeMessage(address, oscArgs);
    try {
      socket.send(msg, target.address, target.port);
      _log('osc sent: $address -> ${target.address.address}:${target.port}');
      return true;
    } catch (_) {}
    _log('osc failed: $address -> ${target.address.address}:${target.port}');
    return false;
  }

  Future<OscTarget?> _resolveTarget() async {
    final raw = oscAddress.trim();
    if (raw.isEmpty) return null;

    final parts = raw.split(':');
    if (parts.length < 2) return null;

    final port = int.tryParse(parts.last);
    final hostStr = parts.sublist(0, parts.length - 1).join(':');
    final host = hostStr.isEmpty ? '127.0.0.1' : hostStr;

    InternetAddress? ip = InternetAddress.tryParse(host);
    if (ip == null) {
      try {
        final res = await InternetAddress.lookup(host);
        if (res.isNotEmpty) ip = res.first;
      } catch (_) {
        return null;
      }
    }

    if (ip == null || port == null) return null;
    return OscTarget(ip, port);
  }

  Future<RawDatagramSocket?> _ensureSocket() async {
    if (_socket != null) return _socket;
    try {
      _socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      return _socket;
    } catch (_) {
      return null;
    }
  }

  List<int> _encodeMessage(String address, List<OscArg> args) {
    final data = <int>[];
    data.addAll(_oscString(address));

    final typeTags = StringBuffer(',');
    for (final a in args) {
      typeTags.write(a.tag);
    }
    data.addAll(_oscString(typeTags.toString()));

    for (final a in args) {
      data.addAll(a.data);
    }
    return data;
  }

  List<int> _oscString(String value) {
    final bytes = utf8.encode(value);
    final padded = <int>[...bytes, 0];
    while (padded.length % 4 != 0) {
      padded.add(0);
    }
    return padded;
  }

  OscArg _argFromValue(Object value) {
    if (value is bool) {
      return OscArg(value ? 'T' : 'F', []);
    } else if (value is int) {
      final bd = ByteData(4)..setInt32(0, value, Endian.big);
      return OscArg('i', bd.buffer.asUint8List().toList());
    } else if (value is double) {
      final bd = ByteData(4)..setFloat32(0, value, Endian.big);
      return OscArg('f', bd.buffer.asUint8List().toList());
    } else if (value is String) {
      return OscArg('s', _oscString(value));
    }
    return OscArg('N', []);
  }

  void dispose() {
    _socket?.close();
    _socket = null;
  }
}
