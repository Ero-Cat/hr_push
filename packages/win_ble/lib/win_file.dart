import 'dart:io';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

class WinServer {
  /// Get path of BleServer from library assets,
  ///  use this class in Flutter projects only, this class is not supported in pure Dart projects.
  /// use [fileName] to avoid conflicts of using same file in different projects
  static Future<String> path({String? fileName}) async {
    String bleServerExe = "packages/win_ble/assets/BLEServer.exe";
    File file = await _getFilePath(bleServerExe, fileName);
    return file.path;
  }

  static Future<File> _getFilePath(String path, String? fileName) async {
    final byteData = await rootBundle.load(path);
    final buffer = byteData.buffer;
    String tempPath = await _tempPath();
    var initPath = '$tempPath/${fileName ?? 'win_ble_server'}.exe';
    var filePath = initPath;

    //Prevent multiple applications and file being occupied, max 10
    for (int i = 1; i < 10; i++) {
      var file = File(filePath);
      if (file.existsSync()) {
        try {
          file.deleteSync();
        } catch (e) {
          filePath = "$initPath$i";
          continue;
        }
        break;
      } else {
        break;
      }
    }

    return File(filePath).writeAsBytes(
        buffer.asUint8List(byteData.offsetInBytes, byteData.lengthInBytes));
  }

  static Future<String> _tempPath() async {
    final dir = await getTemporaryDirectory();
    final path = dir.path;

    if (!Platform.isWindows) {
      return path;
    }

    if (!_hasNonAscii(path)) {
      return path;
    }

    // Windows 用户目录可能包含非 ASCII 字符，导致 BLEServer.exe 启动失败。
    // 退回到一个可写且稳定的 ASCII 目录（Public/ProgramData）。
    final publicBase =
        Platform.environment['PUBLIC'] ?? Platform.environment['PROGRAMDATA'];
    final base = (publicBase != null && publicBase.isNotEmpty)
        ? publicBase
        : r'C:\Users\Public';
    final fallback = Directory('$base\\hr_push_temp');
    if (!fallback.existsSync()) {
      try {
        fallback.createSync(recursive: true);
      } catch (_) {
        // 如果创建失败（极少数权限策略），继续使用原 temp 目录。
        return path;
      }
    }
    return fallback.path;
  }

  static bool _hasNonAscii(String input) {
    for (final codeUnit in input.codeUnits) {
      if (codeUnit > 127) return true;
    }
    return false;
  }
}
