// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Japanese (`ja`).
class AppLocalizationsJa extends AppLocalizations {
  AppLocalizationsJa([String locale = 'ja']) : super(locale);

  @override
  String get appTitle => '心拍数転送';

  @override
  String get currentHeartRate => '現在の心拍数';

  @override
  String get bpmUnit => 'BPM';

  @override
  String get deviceOnline => 'デバイス接続中';

  @override
  String get waitingForConnection => '接続待ち';

  @override
  String get noDeviceConnected => '未接続';

  @override
  String get disconnect => '切断';

  @override
  String get connecting => '接続中...';

  @override
  String get autoReconnecting => '再接続中...';

  @override
  String get connectDevice => '接続';

  @override
  String get signal => '信号';

  @override
  String get nearbyDevices => '近くのデバイス';

  @override
  String get scan => 'スキャン';

  @override
  String get searching => '検索中...';

  @override
  String get noDevicesFound => 'デバイスが見つかりません。';

  @override
  String get rssi => 'RSSI';

  @override
  String get settingsTitle => '設定';

  @override
  String get back => '戻る';

  @override
  String get save => '保存';

  @override
  String get sectionWebHttp => 'Web / HTTP';

  @override
  String get fieldEndpoint => 'エンドポイント';

  @override
  String get fieldInterval => '間隔 (ms)';

  @override
  String get sectionVrchatOsc => 'VRChat OSC';

  @override
  String get fieldAddress => 'アドレス';

  @override
  String get fieldConnectedParam => '接続パラメータ';

  @override
  String get fieldHrValueParam => '心拍数パラメータ';

  @override
  String get fieldHrPercentParam => '心拍数％パラメータ';

  @override
  String get fieldMaxHr => '最大心拍数';

  @override
  String get sectionOscChatbox => 'OSC チャットボックス';

  @override
  String get fieldEnabled => '有効';

  @override
  String get fieldTemplate => 'テンプレート';

  @override
  String get sectionMqtt => 'MQTT クライアント';

  @override
  String get fieldBroker => 'ブローカー';

  @override
  String get fieldPort => 'ポート';

  @override
  String get fieldTopic => 'トピック';

  @override
  String get fieldUsername => 'ユーザー名';

  @override
  String get fieldPassword => 'パスワード';

  @override
  String get fieldClientId => 'クライアントID';

  @override
  String get sectionDebugging => 'デバッグ';

  @override
  String get fieldEnableLogs => 'ログを有効化';

  @override
  String get btnViewLogs => 'ログを表示';

  @override
  String get logsTitle => 'ログ';

  @override
  String get btnClear => 'クリア';

  @override
  String get filterAll => 'すべて';

  @override
  String get filterInfo => '情報';

  @override
  String get filterError => 'エラー';

  @override
  String get unknownDevice => '不明なデバイス';

  @override
  String get signalStrong => '強い信号';

  @override
  String get signalMedium => '良好な信号';

  @override
  String get signalWeak => '弱い信号';
}
