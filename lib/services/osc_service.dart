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
    required this.heartbeatIntPath,
    required this.heartbeatPulsePath,
    required this.heartbeatTogglePath,
    required this.heartbeatIntEnabled,
    required this.heartbeatPulseEnabled,
    required this.heartbeatToggleEnabled,
    required this.heartbeatPulseDuration,
    required this.chatboxEnabled,
    required this.chatboxTemplate,
    this.onLog,
    this.beforeHeartbeatSend,
  });

  final String oscAddress;
  final String hrConnectedPath;
  final String hrValuePath;
  final String hrPercentPath;
  final String heartbeatIntPath;
  final String heartbeatPulsePath;
  final String heartbeatTogglePath;
  final bool heartbeatIntEnabled;
  final bool heartbeatPulseEnabled;
  final bool heartbeatToggleEnabled;
  final Duration heartbeatPulseDuration;
  final bool chatboxEnabled;
  final String chatboxTemplate;
  final void Function(String message, {Object? error})? onLog;
  final Future<void> Function(bool isActive)? beforeHeartbeatSend;

  RawDatagramSocket? _socket;
  StreamSubscription<RawSocketEvent>? _socketSub;
  Completer<bool>? _acknowledgementCompleter;
  DateTime? _lastAcknowledgementAt;
  String? _lastHrConnectedKey;
  DateTime? _lastChatboxSentAt;
  String? _lastChatboxMessage;
  Timer? _heartbeatTimer;
  Timer? _heartbeatInactiveTimer;
  int? _heartbeatBpm;
  bool _heartbeatPulseActive = false;
  bool _heartbeatOutputMayBeActive = false;
  bool _currentBeatToggle = false;
  Future<void> _heartbeatSendQueue = Future<void>.value();
  int _heartbeatWorkGeneration = 0;
  bool _acceptingHeartbeatWork = true;
  bool _isDisposed = false;

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
    if (_isDisposed) return false;
    final last = _lastAcknowledgementAt;
    if (last != null &&
        DateTime.now().difference(last) <= _acknowledgementFreshFor) {
      return true;
    }

    final target = await _resolveTarget();
    if (_isDisposed || target == null) {
      _log('osc acknowledgement target invalid');
      return false;
    }
    final socket = await _ensureSocket();
    if (_isDisposed || socket == null) {
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
      if (_isDisposed) return false;
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
    if (valueOk && percentOk) {
      _startHeartbeatLoop(bpm);
    }
    return valueOk && percentOk;
  }

  /// Stop the heartbeat pulse loop and send inactive values if possible.
  Future<void> stopHeartbeat({bool sendInactive = true}) async {
    final shouldSendInactive = sendInactive && _heartbeatOutputMayBeActive;
    _heartbeatBpm = null;
    _heartbeatPulseActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatInactiveTimer?.cancel();
    _heartbeatInactiveTimer = null;
    _acceptingHeartbeatWork = false;
    final cleanupGeneration = ++_heartbeatWorkGeneration;

    if (shouldSendInactive) {
      await _queueHeartbeatSend(
        _sendHeartbeatInactive,
        generation: cleanupGeneration,
        allowWhileStopped: true,
      );
    } else {
      await _heartbeatSendQueue;
    }
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

  Future<bool> _sendMessage(
    String address,
    Object value, {
    bool Function()? canSend,
  }) async {
    if (_isDisposed || (canSend != null && !canSend())) return false;
    final target = await _resolveTarget();
    if (_isDisposed || (canSend != null && !canSend()) || target == null) {
      _log('osc target invalid: $address');
      return false;
    }
    final socket = await _ensureSocket();
    if (_isDisposed || (canSend != null && !canSend()) || socket == null) {
      _log('osc socket unavailable: $address');
      return false;
    }

    final msg = _encodeMessage(address, [_argFromValue(value)]);
    try {
      if (_isDisposed || (canSend != null && !canSend())) return false;
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

  void _startHeartbeatLoop(int bpm) {
    if (_isDisposed) return;
    if (bpm <= 0) {
      unawaited(stopHeartbeat());
      return;
    }

    if (!_acceptingHeartbeatWork) {
      _acceptingHeartbeatWork = true;
      _heartbeatWorkGeneration++;
    }
    _heartbeatBpm = bpm;
    if (_heartbeatTimer == null && _heartbeatInactiveTimer == null) {
      _scheduleNextHeartbeat(_rrIntervalFor(bpm));
    }
  }

  void _scheduleNextHeartbeat(Duration delay) {
    if (_heartbeatBpm == null) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = Timer(delay, () {
      _heartbeatTimer = null;
      _emitHeartbeat();
    });
  }

  void _emitHeartbeat() {
    final bpm = _heartbeatBpm;
    if (bpm == null || !_acceptingHeartbeatWork || _isDisposed) return;

    _heartbeatPulseActive = true;
    _heartbeatOutputMayBeActive = true;
    final generation = _heartbeatWorkGeneration;
    unawaited(
      _queueHeartbeatSend(_sendHeartbeatActive, generation: generation),
    );

    _heartbeatInactiveTimer?.cancel();
    _heartbeatInactiveTimer = Timer(_qrsIntervalFor(bpm), () {
      _heartbeatInactiveTimer = null;
      unawaited(_completeHeartbeatPulse(generation));
    });

    _scheduleNextHeartbeat(_rrIntervalFor(bpm));
  }

  Future<void> _sendHeartbeatActive(bool Function() canSend) async {
    await beforeHeartbeatSend?.call(true);
    if (!canSend()) return;
    if (heartbeatIntEnabled) {
      await _sendMessageIfPath(heartbeatIntPath, 1, canSend: canSend);
    }
    if (heartbeatPulseEnabled) {
      await _sendMessageIfPath(heartbeatPulsePath, true, canSend: canSend);
    }
    if (heartbeatToggleEnabled) {
      await _sendMessageIfPath(
        heartbeatTogglePath,
        _currentBeatToggle,
        canSend: canSend,
      );
    }
  }

  Future<void> _completeHeartbeatPulse(int generation) async {
    if (!_heartbeatPulseActive || generation != _heartbeatWorkGeneration) {
      return;
    }
    _heartbeatPulseActive = false;
    await _queueHeartbeatSend(_sendHeartbeatInactive, generation: generation);
    _currentBeatToggle = !_currentBeatToggle;
  }

  Future<void> _sendHeartbeatInactive(bool Function() canSend) async {
    await beforeHeartbeatSend?.call(false);
    if (!canSend()) return;
    if (heartbeatIntEnabled) {
      await _sendMessageIfPath(heartbeatIntPath, 0, canSend: canSend);
    }
    if (heartbeatPulseEnabled) {
      await _sendMessageIfPath(heartbeatPulsePath, false, canSend: canSend);
    }
    if (canSend()) _heartbeatOutputMayBeActive = false;
  }

  Future<void> _queueHeartbeatSend(
    Future<void> Function(bool Function() canSend) send, {
    int? generation,
    bool allowWhileStopped = false,
  }) {
    final workGeneration = generation ?? _heartbeatWorkGeneration;
    bool canSend() {
      return !_isDisposed &&
          workGeneration == _heartbeatWorkGeneration &&
          (allowWhileStopped || _acceptingHeartbeatWork);
    }

    final queued = _heartbeatSendQueue.then((_) async {
      if (!canSend()) return;
      await send(canSend);
    });
    _heartbeatSendQueue = queued.catchError((_) {});
    return queued;
  }

  Future<bool> _sendMessageIfPath(
    String address,
    Object value, {
    bool Function()? canSend,
  }) async {
    final path = address.trim();
    if (path.isEmpty) return true;
    return _sendMessage(path, value, canSend: canSend);
  }

  static Duration _rrIntervalFor(int bpm) {
    final milliseconds = (60000 / bpm).round().clamp(1, 60000).toInt();
    return Duration(milliseconds: milliseconds);
  }

  /// Returns a pulse duration that completes before the following heartbeat.
  static Duration heartbeatPulseDurationFor({
    required int bpm,
    required Duration requestedDuration,
  }) {
    if (bpm <= 0) return Duration.zero;
    final rrMs = _rrIntervalFor(bpm).inMilliseconds;
    final maximum = (rrMs - 1).clamp(1, rrMs).toInt();
    final milliseconds = requestedDuration.inMilliseconds
        .clamp(0, maximum)
        .toInt();
    return Duration(milliseconds: milliseconds);
  }

  Duration _qrsIntervalFor(int bpm) {
    return heartbeatPulseDurationFor(
      bpm: bpm,
      requestedDuration: heartbeatPulseDuration,
    );
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
    if (_isDisposed) return null;
    if (_socket != null) return _socket;
    try {
      final socket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      if (_isDisposed) {
        socket.close();
        return null;
      }
      _socket = socket;
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
    if (_isDisposed) return;
    _isDisposed = true;
    _acceptingHeartbeatWork = false;
    _heartbeatWorkGeneration++;
    _heartbeatBpm = null;
    _heartbeatPulseActive = false;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _heartbeatInactiveTimer?.cancel();
    _heartbeatInactiveTimer = null;
    _socketSub?.cancel();
    _socketSub = null;
    _socket?.close();
    _socket = null;
  }
}
