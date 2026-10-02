# 英文取り込み時の動画広告 設計書

- 作成日: 2026-10-02
- 対象: 英文入力画面（`PassageInputView`）の「抽出」

## 1. 目的と成功基準

英文の取り込み（単語抽出・AI による訳と問題の作成）の待ち時間に Google AdMob のインタースティシャル広告を出し、収益化する。

成功基準:

- 「抽出」をタップするたびに、読み込み済みの広告があれば全画面で表示される
- 広告の表示中も抽出処理は進み、広告を閉じた時点で処理が終わっていればすぐ結果画面へ進む
- 広告が無い・失敗した場合でも、抽出は待たされずに今まで通り完了する

## 2. 決めたこと

- 広告フォーマット: インタースティシャル（AdMob の広告ユニット `extraction_interstitial`）
- 頻度: 抽出のたびに毎回（フリークエンシーキャップなし）
- 広告が読み込めていないときは広告を飛ばす（待たせない）
- 起動時に UMP の同意フォーム（必要な地域のみ）→ ATT の許可ダイアログ → AdMob 初期化の順で実行する
- ATT が許可されなくても、パーソナライズされない広告を出す
- パートナー入札（メディエーション）は使わない
- 今回やらないこと: 課金による広告削除、クイズ画面への広告

## 3. 動き方

1. 入力画面を開いたら、広告を1本読み込んでおく
2. 「抽出」で抽出処理と広告表示を同時に始める
3. 広告を閉じたとき、処理が途中なら今と同じ進捗表示を出し、完了したら結果画面へ進む
4. 抽出と広告の両方が終わってから結果画面へ進む。キャンセル時は進まない
5. 表示し終わったら、次回のために次の広告を読み込んでおく

## 4. 構成

`Tangomiru/Ads/`

- `AdConfig`: アプリ ID・広告ユニット ID。Debug ビルドは Google のテスト用 ID、Release ビルドは本番 ID
- `InterstitialAdPresenting`（プロトコル）: `preload()` と `presentIfReady() async`（閉じられるまで待つ。無ければすぐ戻る）
- `GoogleInterstitialAdPresenter`: GoogleMobileAds による実装
- `AdConsent`: 起動時の UMP → ATT → `MobileAds.shared.start()`
- `ExtractionWithAd`: 抽出処理と広告表示を並行に走らせ、両方の完了を待つ（テスト対象）

既存の変更:

- `AppServices`: 広告の担当を1つ持つ
- `TangomiruApp`: 起動時に `AdConsent` を実行
- `PassageInputView`: 表示時に `preload()`、抽出時に `ExtractionWithAd` を使う
- プロジェクト: SPM で `swift-package-manager-google-mobile-ads`（UMP 同梱）を追加。`Tangomiru-Info.plist` に `GADApplicationIdentifier`・`NSUserTrackingUsageDescription`・`SKAdNetworkItems` を追加

本番 ID:

- アプリ ID: `ca-app-pub-8522231452310619~4211205101`
- 広告ユニット ID: `ca-app-pub-8522231452310619/7388118501`

## 5. テスト

- ユニットテスト（偽の広告を使用）: 広告が先に終わる／抽出が先に終わる、どちらでも両方そろってから結果を返す。広告が無いときは待たない
- シミュレーター: テスト用 ID で広告が表示され、閉じると結果画面へ進むことを目視で確認

## 6. リリース前にやること（開発者以外）

- AdMob の管理画面で GDPR の同意メッセージを作成する
- App Store Connect のプライバシー申告を「広告目的のデータ収集あり」に変更する
- リリース後、AdMob で App Store のページと紐づけ、アプリの審査を受ける
