// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => '心率推送';

  @override
  String get currentHeartRate => '当前心率';

  @override
  String get bpmUnit => 'BPM';

  @override
  String get deviceOnline => '设备在线';

  @override
  String get waitingForConnection => '等待连接';

  @override
  String get noDeviceConnected => '未连接设备';

  @override
  String get disconnect => '断开连接';

  @override
  String get connecting => '连接中...';

  @override
  String get autoReconnecting => '自动重连...';

  @override
  String get connectDevice => '连接设备';

  @override
  String get signal => '信号';

  @override
  String get nearbyDevices => '附近设备';

  @override
  String get scan => '扫描';

  @override
  String get searching => '扫描中...';

  @override
  String get noDevicesFound => '未发现设备。';

  @override
  String get rssi => '信号强度';

  @override
  String get settingsTitle => '设置';

  @override
  String get back => '返回';

  @override
  String get save => '保存';

  @override
  String get sectionWebHttp => 'HTTP/WebSocket';

  @override
  String get fieldEndpoint => '推送地址';

  @override
  String get fieldInterval => '间隔 (ms)';

  @override
  String get sectionVrchatOsc => 'VRChat OSC';

  @override
  String get fieldAddress => '接收地址';

  @override
  String get fieldConnectedParam => '在线状态地址';

  @override
  String get fieldHrValueParam => '实时心率地址';

  @override
  String get fieldHrPercentParam => '心率比例地址';

  @override
  String get fieldHeartbeatInt => '整数闪烁';

  @override
  String get fieldHeartbeatIntPath => '整数闪烁地址';

  @override
  String get fieldHeartbeatPulse => '布尔闪烁';

  @override
  String get fieldHeartbeatPulsePath => '布尔闪烁地址';

  @override
  String get fieldHeartbeatToggle => '逐拍翻转';

  @override
  String get fieldHeartbeatTogglePath => '逐拍翻转地址';

  @override
  String get fieldHeartbeatDuration => '闪烁时长 (ms)';

  @override
  String get fieldMaxHr => '最大心率';

  @override
  String get oscStatusTitle => 'OSC 推送';

  @override
  String get oscStatusDisabled => '未启用';

  @override
  String get oscStatusReady => '待发送';

  @override
  String get oscStatusSent => '已发送';

  @override
  String get oscStatusAcknowledged => '已确认';

  @override
  String get oscStatusError => '发送失败';

  @override
  String get sectionOscChatbox => 'OSC 聊天框';

  @override
  String get sectionBackgroundRuntime => '后台运行';

  @override
  String get btnBackgroundRuntime => '后台运行保障';

  @override
  String get fieldEnabled => '启用';

  @override
  String get fieldTemplate => '模板';

  @override
  String get sectionMqtt => 'MQTT 客户端';

  @override
  String get fieldBroker => '服务器 (Broker)';

  @override
  String get fieldPort => '端口';

  @override
  String get fieldTopic => '主题 (Topic)';

  @override
  String get fieldUsername => '用户名';

  @override
  String get fieldPassword => '密码';

  @override
  String get fieldClientId => '客户端 ID';

  @override
  String get sectionDebugging => '调试';

  @override
  String get fieldEnableLogs => '启用日志';

  @override
  String get btnViewLogs => '查看日志';

  @override
  String get logsTitle => '日志';

  @override
  String get btnClear => '清空';

  @override
  String get filterAll => '全部';

  @override
  String get filterInfo => '信息';

  @override
  String get filterError => '错误';

  @override
  String get unknownDevice => '未知设备';

  @override
  String get signalStrong => '信号极佳';

  @override
  String get signalMedium => '信号良好';

  @override
  String get signalWeak => '信号较弱';

  @override
  String get waitingForBluetooth => '等待蓝牙...';

  @override
  String get platformNotSupported => '当前平台暂不支持蓝牙扫描';

  @override
  String get notificationPermissionDenied => '通知权限未授予，无法显示常驻心率卡片';

  @override
  String get pleaseEnableBluetooth => '请开启蓝牙';

  @override
  String get bluetoothNotSupported => '当前平台暂不支持蓝牙';

  @override
  String get bluetoothUnavailable => '蓝牙不可用';

  @override
  String get permissionDenied => '蓝牙/定位权限未授予';

  @override
  String get staleConnectionReconnecting => '连接失活，自动重连...';

  @override
  String get scanningDevices => '扫描附近设备...';

  @override
  String get disconnected => '未连接';

  @override
  String get scanNotSupported => '当前平台不支持蓝牙扫描';

  @override
  String get unnamedDevice => '未命名设备';

  @override
  String get connectNotSupported => '当前平台不支持蓝牙连接';

  @override
  String connectingTo(String device) {
    return '正在连接 $device...';
  }

  @override
  String get deviceConnected => '已连接';

  @override
  String get xiaomiGuideTitle => '未检测到心率服务';

  @override
  String get xiaomiGuideBody =>
      '小米/Redmi 手表需要在手表端开启「心率广播」才会开放标准心率服务：\n\n1. 打开手表的 设置 → 心率，开启「心率广播」（部分型号为「分享心率」）\n2. 确认手表未被小米运动健康 App 占用连接\n3. 回到此处重新扫描并连接';

  @override
  String get xiaomiGuideRescan => '重新扫描';

  @override
  String get xiaomiGuideGotIt => '我知道了';
}
