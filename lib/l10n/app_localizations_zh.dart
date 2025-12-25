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
  String get fieldAddress => 'OSC 地址';

  @override
  String get fieldConnectedParam => '在线参数';

  @override
  String get fieldHrValueParam => '心率参数';

  @override
  String get fieldHrPercentParam => '心率百分比参数';

  @override
  String get fieldMaxHr => '最大心率';

  @override
  String get sectionOscChatbox => 'OSC 聊天框';

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
}
