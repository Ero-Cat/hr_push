# HR PUSH / 心拍プッシュ

![Release](https://img.shields.io/github/v/release/Ero-Cat/hr_push?display_name=tag)
![License](https://img.shields.io/github/license/Ero-Cat/hr_push)
![Flutter](https://img.shields.io/badge/Flutter-3.10%2B-02569B?logo=flutter&logoColor=white)
![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20macOS%20%7C%20Windows%20%7C%20Linux-0ea5e9)
![Protocols](https://img.shields.io/badge/Protocols-HTTP%2FWS%20%7C%20OSC%20%7C%20MQTT-10b981)
![BLE](https://img.shields.io/badge/BLE-Heart%20Rate-ef4444)

[中文](README.md) | [English](README_EN.md) | **日本語**

Flutter で開発されたクロスプラットフォームの BLE 心拍モニタ＆プッシュツールです。心拍デバイスに接続すると、リアルタイム BPM、オンライン状態、心拍率を **HTTP/WS・OSC・MQTT** に配信できます。

<div align="center">
  <img src="images/logo.png" alt="HR PUSH logo" width="140" />
</div>

## 🗺️ 利用シーン
- **常時プッシュ**：常時稼働の Mac mini や Windows PC 上で動作。腕時計の心拍ブロードキャストが有効なら、範囲内に入るだけで自動接続して配信します。
- **VRChat / カスタム連携**：OSC や HTTP/WS/MQTT を使ってパラメータ連動や UI 表示に利用できます。

## 📷 プレビュー

| ホーム | 設定 |
| --- | --- |
| ![Home](images/main.png) | ![Settings](images/settings.png) |

## ✨ 主な機能
- **BLE スキャン＆接続**：不要な広告を除外し、心拍サービスや一般的なウェアラブルを優先。
- **自動再接続**：直近デバイスを記憶し、切断やデータ停止時に自動再接続。
- **リアルタイム表示**：BPM、最終更新時刻、RSSI。RSSI 取得は更新間隔に連動。
- **複数プロトコル対応（任意）**
  - **HTTP/WS**：`http(s)://` / `ws(s)://` を指定して JSON 送信。
  - **OSC**：`host:port` を指定（空で無効）。UI は `127.0.0.1:9000` を推奨。
  - **MQTT**：Broker を指定（空で無効）。ポート/Topic/ユーザー/パス/Client ID を設定可能。
- **デバッグ表示**：近傍広告、Service UUID、RSSI、メーカー情報長を表示。
- **デスクトップ最適化**：Windows/macOS/Linux で縦長固定。Windows はトレイ対応。
- **Android 常駐通知**：接続時に通知バーへ心拍表示、更新間隔で更新。

## 🚀 クイックスタート（ユーザー向け）
1. アプリを起動し「再スキャン」をタップ。
2. 心拍デバイスを選択して接続。
3. 設定で送信先（HTTP/WS、OSC、MQTT）を入力して保存。

> 接続不可でブロードキャストのみのデバイスは「ブロードキャストデバッグ」で確認可能。送信は接続と購読後に行われます。

## 🧰 使い方
### 接続と再接続
- 「再スキャン」で近傍デバイス一覧を更新。
- 「クイック接続」は RSSI が高い / 直近出現デバイスを優先。
- 心拍更新が長時間止まるとオフライン判定し自動再接続。

### 送信データ形式
すべてのプロトコルは同じ JSON を送信します。

- 心拍イベント
```json
{
  "event": "heartRate",
  "heartRate": 85,
  "percent": 0.42,
  "connected": true,
  "device": "Polar H10",
  "timestamp": "2025-12-12T09:00:00.000Z"
}
```

- 接続イベント
```json
{
  "event": "connection",
  "connected": false,
  "device": "Polar H10",
  "timestamp": "2025-12-12T09:05:00.000Z"
}
```

`percent = heartRate / 最大心拍`（0-1）。

### 設定項目
| 項目 | 説明 | 既定値 |
| --- | --- | --- |
| HTTP/WS 送信 URL | 空で無効、`http(s)`/`ws(s)` 対応 | 空 |
| OSC 送信先 | `host:port`、空で無効、UI 推奨値あり | 空（推奨 `127.0.0.1:9000`） |
| OSC パス：オンライン | bool | `/avatar/parameters/hr_connected` |
| OSC パス：心拍 | int BPM | `/avatar/parameters/hr_val` |
| OSC パス：心拍率 | float 0-1 | `/avatar/parameters/hr_percent` |
| OSC ChatBox トグル | 有効時に `/chatbox/input` へ送信 | オフ |
| OSC ChatBox テンプレート | `{hr}`/`{percent}` 対応、最大 144 文字 / 9 行 | `💓{hr}` |
| MQTT Broker | 空で無効、`mqtt://host:port` or host | 空 |
| MQTT ポート | Broker にポートが無い場合に使用 | `1883` |
| MQTT Topic | JSON 送信 | `hr_push` |
| MQTT ユーザー/パス | 任意 | 空 |
| MQTT Client ID | 空なら自動生成 | 空 |
| 最大心拍 | 率計算用 | `200` |
| 更新間隔 (ms) | UI/送信/RSSI の間隔 | `1000` |

## 🎮 VRChat（OSC）
- 推奨 OSC パラメータプラグイン：[booth.pm/zh-cn/items/5531594](https://booth.pm/zh-cn/items/5531594)
- またはアバター側で上記 OSC パスを監視してください。

### スクリーンショット
<img src="images/vrchat.png" alt="VRChat OSC" width="900" />

#### Android ステータスバー
<img src="images/android.jpeg" alt="Android" />

## 🧩 デバイス互換性
### 検証済みデバイス
**送信側（心拍ブロードキャスト）**
1. Garmin Enduro 2

**受信側**
1. iPhone 15 Pro（自己署名）
2. OnePlus Ace（ColorOS / Android 14）
3. MacBook Pro M5（macOS Tahoe 26.1）
4. Windows（B450I GAMING PLUS AC Bluetooth）

### 既知の制限
- **Mi Smart Band 系列**：標準 BLE Heart Rate Service を公開しないことが多く、認証付きの独自プロトコルが必要なため本プロジェクトでは直接対応できません。

## 🛡️ 対応プラットフォームと権限
- **Android**：BLE スキャン/接続権限が必要（Android 12+ は位置情報不要、11 以下は位置情報が必要）。Android 13+ は通知権限を許可してください。
  - ColorOS/一部 OEM ROM：通知・バックグラウンド・自動起動の許可が必要な場合があります。
- **iOS/macOS**：初回起動時に Bluetooth 権限を要求します。

## 🔧 開発とビルド
- 主要コード：`lib/main.dart`（UI）、`lib/heart_rate_manager.dart`（スキャン/接続/送信）。
- 依存関係：`flutter pub get`。
- 実行：`flutter run -d <device>`。
- テスト：`flutter test`。
- ビルド：`flutter build apk|ios|windows|macos|linux`。
- コードスタイル：2 スペース、`dart format .`、`flutter_lints`。

## ⚠️ 既知の問題
- Windows では非 ASCII パスで実行失敗する場合があります。英数字パス推奨。

## 🧾 更新履歴
### v1.3.4
- OSC：ChatBox 心拍表示（`{hr}/{percent}` テンプレート、節流/重複抑制）。
- UI：ChatBox トグル＆テンプレート入力追加、旧文言を削除。
- ドキュメント：README 改訂、MIT License 追加、.gitignore 追加。

### v1.3.3
- UI：アプリ名を「心拍プッシュ」に統一。
- UI：ホーム/設定のレイアウト調整。
- OSC：心拍送信時にオンライン状態を強制同期。
- Android：通知チャンネル更新。
- CI：Release の未署名 iOS を削除。
- Release：成果物名を `hr-push` に統一（macOS/Windows）。
- ドキュメント：VRChat/Android スクショ、動作確認デバイス、Windows 非 ASCII 問題。

### v1.3.1
- Windows：トレイアイコンでウィンドウ復帰。
- Windows：自動再接続の安定性改善。
- UI：不要な再描画を削減。
- OSC：`/avatar/parameters/hr_connected` の実態追従改善。

### v1.3.0
- MQTT 送信追加。
- Android：常駐通知に心拍表示。
- RSSI 取得間隔を設定と同期。
- 再接続ロジック改善。
- Windows：非 ASCII パスでの安定性改善。

### v1.2.2
- Windows：最小化でトレイ常駐。
- Android：R8/リソース圧縮/ABI 分割。Windows/macOS/iOS はリンク最適化。

### v1.2.1
- Windows：心拍停止時の自動再接続。

### v1.2.0
- `images/logo.png` を全プラットフォームのアイコンに採用。
- Windows：未フォーカス時のアニメ停止と自動再接続。
- README：Windows パス注意点を追加。
- 依存：`flutter_launcher_icons` のデスクトップ対応。

## 📜 ライセンス
MIT License。詳細は `LICENSE`。

## 🌐 他言語 README
- Chinese: [README.md](README.md)
- English: [README_EN.md](README_EN.md)

## 🤝 フィードバック
Issue / PR を歓迎します。デバイスや環境情報、ログがあると再現がスムーズです。
