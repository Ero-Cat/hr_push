import 'package:flutter_loggy/flutter_loggy.dart';
import 'package:loggy/loggy.dart' as loggy;

class AppLog {
  static final AppStreamPrinter _streamPrinter =
      AppStreamPrinter(const PrettyDeveloperPrinter());
  static bool _enabled = false;
  static bool _initialized = false;

  static void init({required bool enabled}) {
    _enabled = enabled;
    _initialized = true;
    loggy.Loggy.initLoggy(
      logPrinter: _streamPrinter,
      logOptions:
          loggy.LogOptions(enabled ? loggy.LogLevel.all : loggy.LogLevel.off),
    );
  }

  static void setEnabled(bool enabled) {
    _enabled = enabled;
    if (!_initialized) {
      init(enabled: enabled);
      return;
    }
    loggy.Loggy.initLoggy(
      logPrinter: _streamPrinter,
      logOptions:
          loggy.LogOptions(enabled ? loggy.LogLevel.all : loggy.LogLevel.off),
    );
    if (!enabled) {
      clear();
    }
  }

  static bool get enabled => _enabled;

  static StreamPrinter get streamPrinter => _streamPrinter;

  static void clear() {
    _streamPrinter.clear();
  }

  static void debug(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enabled) return;
    loggy.logDebug(message, error, stackTrace);
  }

  static void info(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enabled) return;
    loggy.logInfo(message, error, stackTrace);
  }

  static void warning(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enabled) return;
    loggy.logWarning(message, error, stackTrace);
  }

  static void error(String message, {Object? error, StackTrace? stackTrace}) {
    if (!_enabled) return;
    loggy.logError(message, error, stackTrace);
  }
}

class AppStreamPrinter extends StreamPrinter {
  AppStreamPrinter(super.childPrinter, {this.maxRecords = 800});

  final int maxRecords;

  @override
  void onLog(loggy.LogRecord record) {
    super.onLog(record);
    final records = logRecord.value;
    if (records.length <= maxRecords) return;
    logRecord.value = records.take(maxRecords).toList(growable: false);
  }

  void clear() {
    logRecord.value = <loggy.LogRecord>[];
  }
}
