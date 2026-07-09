import 'dart:async';
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
  StreamSubscription<RawSocketEvent>? _socketSub;
  Completer<bool>? _acknowledgementCompleter;
  DateTime? _lastAcknowledgementAt;
  String? _lastHrConnectedKey;
  DateTime? _lastChatboxSentAt;
  String? _lastChatboxMessage;

  static const Duration _chatboxMinInterval = Duration(seconds: 2);
  static const Duration _acknowledgementFreshFor = Duration(seconds: 10);
  static const String acknowledgementPingPath = '/hr_push/ping';
  static const String acknowledgementPongPath = '/hr_push/pong';

  bool get isEnabled => oscAddress.trim().isNotEmpty;

  void _log(String message, {Object? error}) {
    onLog?.call(message, error: error);
    AppLog.info(message);
  }

  Future<bool> requestAcknowledgement({required Duration timeout}) async {
    final last = _lastAcknowledgementAt;
    if (last != null &&
        DateTime.now().difference(last) <= _acknowledgementFreshFor) {
      return true;
    }

    final target = await _resolveTarget();
    if (target == null) {
      _log('osc acknowledgement target invalid');
      return false;
    }
    final socket = await _ensureSocket();
    if (socket == null) {
      _log('osc acknowledgement socket unavailable');
      return false;
    }

    final pending = _acknowledgementCompleter;
    if (pending != null && !pending.isCompleted) {
      return pending.future.timeout(timeout, onTimeout: () => false);
    }

    final completer = Completer<bool>();
    _acknowledgementCompleter = completer;
    final msg = _encodeMessage(acknowledgementPingPath, const []);
    try {
      socket.send(msg, target.address, target.port);
      _log(
        'osc acknowledgement ping -> ${target.address.address}:${target.port}',
      );
    } catch (e) {
      _log('osc acknowledgement failed', error: e);
      if (!completer.isCompleted) completer.complete(false);
    }

    return completer.future.timeout(
      timeout,
      onTimeout: () {
        if (!completer.isCompleted) completer.complete(false);
        _log('osc acknowledgement timeout');
        return false;
      },
    );
  }

  /// Send connection status
  Future<bool> sendConnectedStatus(bool connected, {bool force = false}) async {
    final key = '${oscAddress.trim()}|$hrConnectedPath|$connected';
    if (!force && _lastHrConnectedKey == key) return true;

    final ok = await _sendMessage(hrConnectedPath, connected);
    if (ok) {
      _lastHrConnectedKey = key;
    }
    return ok;
  }

  /// Send heart rate value and percent
  Future<bool> sendHeartRate(int bpm, double? percent) async {
    final valueOk = await _sendMessage(hrValuePath, bpm);
    var percentOk = true;
    if (percent != null) {
      percentOk = await _sendMessage(hrPercentPath, percent);
    }
    return valueOk && percentOk;
  }

  /// Send chatbox message if enabled
  Future<bool> sendChatbox(int bpm, double? percent) async {
    if (!chatboxEnabled) return true;

    final text = _buildChatboxText(bpm, percent);
    if (text.trim().isEmpty) return true;
    if (text == _lastChatboxMessage) return true;

    final now = DateTime.now();
    if (_lastChatboxSentAt != null &&
        now.difference(_lastChatboxSentAt!) < _chatboxMinInterval) {
      return true;
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
    return ok;
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
      _socketSub = _socket?.listen(_handleSocketEvent);
      return _socket;
    } catch (_) {
      return null;
    }
  }

  void _handleSocketEvent(RawSocketEvent event) {
    if (event != RawSocketEvent.read) return;
    while (true) {
      final packet = _socket?.receive();
      if (packet == null) return;
      final address = _readOscAddress(packet.data);
      if (address != acknowledgementPongPath) continue;
      _lastAcknowledgementAt = DateTime.now();
      final pending = _acknowledgementCompleter;
      if (pending != null && !pending.isCompleted) {
        pending.complete(true);
      }
      _log(
        'osc acknowledgement pong <- ${packet.address.address}:${packet.port}',
      );
    }
  }

  String? _readOscAddress(Uint8List data) {
    final end = data.indexOf(0);
    if (end <= 0) return null;
    try {
      return utf8.decode(data.sublist(0, end));
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
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
  }
}
