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
  String get fieldAddress => '受信アドレス';

  @override
  String get fieldConnectedParam => 'オンライン状態アドレス';

  @override
  String get fieldHrValueParam => 'リアルタイム心拍数アドレス';

  @override
  String get fieldHrPercentParam => '心拍数比率アドレス';

  @override
  String get fieldHeartbeatInt => '整数フラッシュ';

  @override
  String get fieldHeartbeatIntPath => '整数フラッシュのアドレス';

  @override
  String get fieldHeartbeatPulse => '真偽値フラッシュ';

  @override
  String get fieldHeartbeatPulsePath => '真偽値フラッシュのアドレス';

  @override
  String get fieldHeartbeatToggle => '拍ごとの切り替え';

  @override
  String get fieldHeartbeatTogglePath => '拍ごとの切り替えアドレス';

  @override
  String get fieldHeartbeatDuration => 'フラッシュ時間 (ms)';

  @override
  String get fieldMaxHr => '最大心拍数';

  @override
  String get oscStatusTitle => 'OSC送信';

  @override
  String get oscStatusDisabled => '無効';

  @override
  String get oscStatusReady => '待機中';

  @override
  String get oscStatusSent => '送信済み';

  @override
  String get oscStatusAcknowledged => '確認済み';

  @override
  String get oscStatusError => '送信失敗';

  @override
  String get sectionOscChatbox => 'OSC チャットボックス';

  @override
  String get sectionBackgroundRuntime => 'バックグラウンド実行';

  @override
  String get btnBackgroundRuntime => 'バックグラウンド実行を保護';

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

  @override
  String get waitingForBluetooth => 'Bluetooth待機中...';

  @override
  String get platformNotSupported => 'このプラットフォームはBluetoothに対応していません';

  @override
  String get notificationPermissionDenied => '通知権限が拒否されました';

  @override
  String get pleaseEnableBluetooth => 'Bluetoothをオンにしてください';

  @override
  String get bluetoothNotSupported => 'Bluetooth非対応';

  @override
  String get bluetoothUnavailable => 'Bluetoothは利用できません';

  @override
  String get permissionDenied => 'Bluetooth/位置情報の権限が拒否されました';

  @override
  String get staleConnectionReconnecting => '接続がタイムアウト、再接続中...';

  @override
  String get scanningDevices => 'デバイスをスキャン中...';

  @override
  String get disconnected => '未接続';

  @override
  String get scanNotSupported => 'スキャン非対応';

  @override
  String get unnamedDevice => '名前のないデバイス';

  @override
  String get connectNotSupported => '接続非対応';

  @override
  String connectingTo(String device) {
    return '$deviceに接続中...';
  }

  @override
  String get deviceConnected => '接続済み';

  @override
  String get xiaomiGuideTitle => '心拍数サービスが見つかりません';

  @override
  String get xiaomiGuideBody =>
      'Xiaomi/Redmi ウォッチは、本体で「心拍数ブロードキャスト」を有効にすると初めて標準の心拍数サービスを公開します：\n\n1. ウォッチの 設定 → 心拍数 で「心拍数ブロードキャスト」をオンにします\n2. ウォッチが Mi Fitness アプリに接続されていないことを確認します\n3. ここに戻って再スキャンし、接続してください';

  @override
  String get xiaomiGuideRescan => '再スキャン';

  @override
  String get xiaomiGuideGotIt => '了解しました';

  @override
  String get sectionGeneral => '全般';

  @override
  String get showAdvanced => '詳細設定を表示';

  @override
  String get hideAdvanced => '詳細設定を閉じる';

  @override
  String get hintOscEmpty => '空欄で OSC プッシュは無効になります';

  @override
  String get btnFillDefault => 'デフォルトを使用';

  @override
  String get btnTest => 'テスト';

  @override
  String get testSuccess => 'テスト成功';

  @override
  String get testFailed => '失敗';

  @override
  String get hintOscNote => 'OSC はコネクションレスのため、テストはデータグラムの送信可否のみ検証します';

  @override
  String get errInvalidUrl => '有効な http/https/ws/wss URL を入力してください';

  @override
  String get errInvalidOscAddress => '形式は host:port（ポート 1-65535）です';

  @override
  String get errInvalidOscPath => 'OSC パスは / で始まる必要があります';

  @override
  String get errInvalidPort => 'ポートは 1-65535 の範囲で入力してください';

  @override
  String get errInvalidInterval => '間隔は 250-60000 ms の範囲で入力してください';

  @override
  String get errInvalidMaxHr => '最大心拍数は 100-250 の範囲で入力してください';

  @override
  String get errInvalidPulseDuration => '点滅時間は 20-1000 ms の範囲で入力してください';

  @override
  String get unsavedTitle => '未保存の変更';

  @override
  String get unsavedBody => '画面を離れると変更が破棄されます。続行しますか？';

  @override
  String get unsavedDiscard => '破棄';

  @override
  String get unsavedKeepEditing => '編集を続ける';

  @override
  String get savedToast => '設定を保存しました';

  @override
  String get fixErrorsBeforeSave => '赤く表示された項目を先に修正してください';

  @override
  String get fieldMqttTls => 'TLS を使用 (mqtts)';

  @override
  String get fieldMqttLwtTopic => 'LWT トピック（任意）';

  @override
  String get hintMqttLwt => '異常切断時にこのトピックへオフラインメッセージを発行します';

  @override
  String get hintClientId => '空欄の場合デフォルトのクライアント ID を使用します';

  @override
  String get showPassword => 'パスワードを表示';

  @override
  String get onbSkip => 'スキップ';

  @override
  String get onbNext => '次へ';

  @override
  String get onbDone => '始める';

  @override
  String get onbTitle1 => 'HR PUSH へようこそ';

  @override
  String get onbBody1 =>
      '心拍ストラップやウォッチの心拍数をリアルタイムで読み取り、HTTP/WebSocket・VRChat OSC・MQTT へプッシュします。';

  @override
  String get onbTitle2 => 'デバイスを接続';

  @override
  String get onbBody2 =>
      '心拍デバイスを装着し、「近くのデバイス」一覧からタップして接続します。\n\nXiaomi/Redmi ウォッチは、先に本体で「心拍数ブロードキャスト」を有効にしてください（設定 → 心拍数）。';

  @override
  String get onbTitle3 => 'プッシュを設定';

  @override
  String get onbBody3 =>
      '設定から Webhook・OSC・MQTT のアドレスを入力し、「テスト」ボタンで接続を確認します。保存後はリアルタイムでプッシュされます。';
}
