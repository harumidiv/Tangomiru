# 広告なしプラン（月額課金）設計書

- 作成日: 2026-10-02
- 前提: [英文取り込み時の動画広告 設計書](2026-10-02-extraction-ads-design.md) の広告（取り込み中・クイズ結果）

## 1. 目的と成功基準

月額のサブスクリプションを購入した人には、アプリ内のすべての広告を表示しない。

成功基準:

- 購入すると、取り込み中の広告もクイズ結果の広告も出なくなる（読み込みもしない）
- 解約・期限切れ・返金で、広告がまた出るようになる
- 購入・復元・解約の管理が、ライブラリ画面からたどれる購入画面でできる

## 2. 決めたこと

- 特典は「広告が出なくなる」だけ
- 商品: 自動更新サブスクリプション1つ。商品 ID `harumidiv.Tangomiru.adFree.monthly`、グループ「広告なし」。価格は App Store Connect で設定
- 購入画面: Apple の `SubscriptionStoreView`（上部の説明だけ自作）
- 入口: ライブラリ画面右上の王冠ボタン → シート
- 購入済みの人には、起動時の同意フォーム・ATT・広告の読み込みを行わない
- プライバシーポリシー: `https://harumidiv.github.io/AppleStoreDevelopprSite/privacy-tangomiru.html`
- 利用規約: Apple の標準 EULA（`https://www.apple.com/legal/internet-services/itunes/dev/stdeula/`）
- 今回やらないこと: 買い切り・年額・無料お試し

## 3. 構成

`Tangomiru/Store/`

- `StoreConfig`: 商品 ID、プライバシーポリシー・利用規約の URL
- `AdFreeStatus`: 権利（商品 ID・期限・返金日）の一覧と現在時刻から、広告なしにすべきかを判定する純粋な関数
- `PurchaseManager`（`@Observable`）: 起動時に `Transaction.currentEntitlements` で `isAdFree` を決め、`Transaction.updates` で購入・更新・返金を反映する
- `AdFreeStoreView`: `SubscriptionStoreView` による購入画面（復元ボタン、ポリシーへのリンク）

`Tangomiru/Ads/`

- `AdFreeGatedPresenter`: 既存の広告を包み、広告なしなら `preload()` も `presentIfReady()` も何もしない

既存の変更:

- `AppServices`: `PurchaseManager` を持ち、2つの広告を `AdFreeGatedPresenter` で包む（取り込み画面・クイズ画面は変更なし）
- `TangomiruApp`: 起動時に購入状態を確認し、広告なしでなければ同意・ATT・広告の読み込みを行う
- `LibraryView`: 王冠ボタンと購入画面のシート
- `Tangomiru.storekit` とスキームの設定（ローカルで購入を試すため）

既知の制約: 起動中に解約された場合、その起動中は同意を取っていないため広告が出ないことがある（次回起動から出る）。

## 4. テスト

- ユニットテスト: `AdFreeStatus`（有効・期限切れ・返金・別商品）、`AdFreeGatedPresenter`（広告なしなら読み込み・表示しない、そうでなければ委譲する）
- シミュレーター（`.storekit`）: 購入で広告が止まる、Xcode の取引マネージャでの解約・返金で戻る、復元が動く

## 5. リリース前にやること（開発者以外）

- App Store Connect で有料アプリ契約・銀行口座・税務情報を登録
- サブスクリプショングループと商品の作成（価格、表示名、説明、審査用スクリーンショット）
- タンゴミル用プライバシーポリシーの公開
- アプリの説明欄に利用規約（EULA）へのリンクを記載
