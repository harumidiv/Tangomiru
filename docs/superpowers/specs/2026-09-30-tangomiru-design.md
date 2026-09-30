# Tangomiru 設計書

- 作成日: 2026-09-30
- 対象: iOS 26.2 以降 / SwiftUI / SwiftData

## 1. 目的と成功基準

ユーザーがコピペした英文から英単語・熟語を抽出し、4択クイズ（英語 → 日本語の意味）で覚え、最終的にその英文を読めるようになるためのアプリ。

成功基準:

- 英文を貼り付けると、基本語を除いた単語・熟語が意味付きで抽出される
- 抽出語でクイズを繰り返すと各語の状態が上がり、英文ごとの習得率が上がっていく
- 読解モードで、まだ覚えていない語だけがハイライトされ、タップで意味を確認しながら元の英文を読める
- Apple Intelligence 非対応端末（iPhone 15 以前など）でも、辞書ベースで全機能が動く

想定ユーザー: 日本語話者の英語学習者。

## 2. 方針（案1: 辞書ベース共通 + Foundation Models で上乗せ）

- 抽出の土台は全端末共通: NaturalLanguage（トークン化・原形化・品詞・固有名詞判定）+ 同梱の EJDict 辞書。
- Foundation Models（`SystemLanguageModel.default`）が available な端末では、上乗せとして
  - 辞書で拾えなかった熟語の追加抽出
  - 文脈に合った訳の選定
  - 紛らわしい誤答3つの生成
  を行う。
- AI が使えない・失敗した場合は、常に辞書の結果にフォールバックする（一方が壊れても機能が止まらない）。

## 3. 画面構成

NavigationStack 1本（TabView なし）。

```
① 英文ライブラリ（一覧）
   ├ ＋ → ② 英文入力（タイトル＋本文）→「抽出」
   │        ↓ 抽出中インジケータ
   │      ③ 抽出結果確認（語一覧＋出題ON/OFF）→「保存」
   └ 行タップ → ④ 英文詳細
                 ├ 習得率と内訳（覚えた / うろ覚え / 苦手 / 超苦手 / 未学習）
                 ├ 出題数セグメント（10問 / 20問 / 全問）＋「クイズを始める」→ ⑤ 4択クイズ → ⑥ 結果
                 ├「読解モード」→ ⑦ 本文表示
                 └「単語一覧」→ ③ と同じ画面（ON/OFF 変更・状態確認）
```

- ① 各行: タイトル、習得率バー、最終学習日。スワイプで削除。
- ② タイトル未入力時は本文先頭から自動生成。本文が空、または 10,000 文字超の場合は案内を出し抽出不可。
- ③ 各行: 見出し語、意味、状態、出題ON/OFF トグル。辞書モードで抽出した場合は「辞書モードで抽出しました」と小さく表示。
- ⑤ 上部に「×」と10秒のカウントダウンメーター、中央のカードに見出し語（英語音声で読み上げ）、右下に SKIP、番号付きの日本語4択。解答すると正解を ○、選んだ不正解を × で約1秒表示して自動で次へ。10秒経過・SKIP は不正解扱い。
- ⑥ 正答数、間違えた語の一覧と「間違えたN問を復習する」ボタン（復習の回はスコアを変えない）、状態が上がった／下がった語の一覧。
- ⑦ 「覚えた」以外の語をハイライト（超苦手=濃い赤＋太字、苦手=赤系、うろ覚え=黄系、未学習=グレー系）。タップで小さなシート（`presentationDetents`）に意味と状態を表示（SwiftUI の `Text` 内リンクには位置指定のポップオーバーを付けられないため）。

## 4. 習得状態とスコアルール

| score | 状態 |
|---|---|
| nil | 未学習（未出題） |
| -1 | 超苦手 |
| 0 | 苦手 |
| 1 | うろ覚え |
| 2 | 覚えた |

- 意味は本文での品詞に合う訳を1つだけ、括弧の補足なしで表示する（AI 利用時は文脈訳1つ）。
- 初回出題: 正解 → 1、不正解 → 0
- 2回目以降: 正解 → +1（上限 2）、不正解 → −1（下限 −1）
- 例: 覚えた(2) で不正解 → うろ覚え(1) に降格。苦手(0) で正解 → うろ覚え(1)。苦手(0) で不正解 → 超苦手(−1)。超苦手(−1) で正解 → 苦手(0)。
- 習得率 = 出題ON の語のうち「覚えた」の割合。
- 状態の追加・変更は数値範囲の変更だけで済むよう、ルールは `ScoreRule` に閉じ込める。

## 5. データ構造（SwiftData）

```swift
@Model final class Passage {
    var title: String
    var body: String
    var createdAt: Date
    var lastStudiedAt: Date?
    var usedAI: Bool                         // 抽出時に AI 上乗せが行われたか
    @Relationship(deleteRule: .cascade) var items: [VocabItem]
}

@Model final class VocabItem {
    var term: String            // 見出し語（原形 or 熟語）
    var meaning: String         // 文脈に合った日本語訳
    var distractors: [String]   // AI 生成の誤答（辞書モードでは空）
    var contextSentence: String // 本文中の最初の出現文
    var occurrences: [TextSpan] // 本文中の出現位置（UTF-16 offset + length）
    var isEnabled: Bool         // 出題ON/OFF（初期値 true）
    var score: Int?             // nil / -1 / 0 / 1 / 2
    var source: ItemSource      // .dictionary / .ai
}

struct TextSpan: Codable, Hashable { var location: Int; var length: Int }
enum ItemSource: String, Codable { case dictionary, ai }
```

- 同じ語でも英文ごとに別レコード（英文ごとの習得率と文脈訳を保つため）。

## 6. 抽出パイプライン（ExtractionPipeline）

入力: 本文。出力: `[ExtractedItem]`（`VocabItem` 生成前の値型）と `usedAI: Bool`。

1. **トークン化**: `NLTagger`（`.lemma`, `.lexicalClass`, `.nameType`）で各単語の表層形・原形・品詞・固有名詞フラグ・範囲・所属文を得る。原形が取れない場合は小文字化した表層形を使う。
2. **熟語照合**: 連続 4 → 3 → 2 語の原形列を EJDict の熟語見出しと照合し、長い一致を優先。熟語に含まれたトークンは単語照合から除外。
3. **単語照合**: 原形で EJDict を引く。除外対象: 基本語リスト（約2,000語）、固有名詞、数字・記号、辞書に無い語。
4. **重複統合**: 同じ見出し語は1件にまとめ、全出現位置を `occurrences` に、最初の出現文を `contextSentence` にする。
5. **AI 上乗せ**（`VocabEnricher`）: Foundation Models が available な場合のみ。
   - 抽出語を約15語ずつのチャンクに分けて依頼（コンテキスト長対策）。
   - `@Generable` な出力: 各語の文脈訳・誤答3つ、および辞書で拾えなかった熟語（見出し語・訳・誤答）。
   - AI が返した熟語は本文中に実在するか（大文字小文字無視の部分一致）を検証し、実在しないものは捨てる。
   - チャンク単位で失敗（生成エラー・ガードレール）した場合、そのチャンクは辞書結果のまま進める。

### 辞書データ

- EJDict（パブリックドメイン）の TSV（約5MB、`見出し\t訳`）をバンドル同梱。
- 抽出時にメモリへ読み込み、単語用・熟語用（空白を含む見出し）の辞書を構築する。
- 訳は「 / 」区切りで複数あるため、辞書モードでの表示は先頭1〜2個に整形する。

### 基本語リスト

- EJDict リポジトリ（CC0）の `frequency/2000.txt`（基本語約2,000語、中学英語レベル相当）を `basic_words.txt` として同梱。

## 7. クイズ（QuizEngine）

UI 非依存の純粋ロジックとして実装する。

- **出題数**: 10問 / 20問 / 全問から選択（初期値10問、最後の選択を `@AppStorage` で保持）。出題ON の語が選択数より少なければある分だけ。
- **選び方**: 出題ON の語を 超苦手 → 苦手 → 未学習 → うろ覚え → 覚えた の優先順で選び、同じ状態内はランダム。
- **復習**: 回の途中で問題は増やさない。間違えた語（時間切れ・SKIP 含む）は終了後の結果画面から復習の回として出題し、復習の回はスコアを変えない。
- **選択肢**: 正解1 + 誤答3 をシャッフル。誤答の優先順:
  1. その語の AI 生成誤答
  2. 同じ英文内の別の語の訳
  3. 辞書からランダムな訳
  正解と同じ文字列、および誤答同士の重複は除外する。
- **スコア更新**: `ScoreRule.apply(score: Int?, correct: Bool) -> Int`。
- クイズ終了時に `Passage.lastStudiedAt` を更新。

## 8. エラー処理

| 状況 | 挙動 |
|---|---|
| Foundation Models 不可（非対応端末・AI オフ・モデル準備中） | 何も言わず辞書のみで抽出。③ に「辞書モードで抽出しました」 |
| AI チャンクの生成失敗・ガードレール | そのチャンクのみ辞書結果で継続 |
| 抽出結果 0 件 | 「出題できる語が見つかりませんでした」を表示し保存不可 |
| 本文が空 / 10,000 文字超 | ② で案内、抽出ボタン無効 |
| 辞書ファイル読み込み失敗 | 抽出不可のエラーを表示（バンドル破損時のみ） |

## 9. モジュール構成

```
Tangomiru/
  App/            TangomiruApp, ルート View
  Models/         Passage, VocabItem, TextSpan, ItemSource, MasteryState
  Domain/         ScoreRule, QuizEngine, ChoiceBuilder
  Extraction/     Tokenizer, WordDictionary(EJDict ローダ), BasicWords,
                  DictionaryExtractor, VocabEnricher(protocol),
                  FoundationModelsEnricher, ExtractionPipeline
  Features/       Library, Input, Review, Detail, Quiz, Result, Reading の各 View
  Resources/      ejdict.tsv, basic_words.txt
TangomiruTests/   Swift Testing
```

- `VocabEnricher` プロトコルで Foundation Models を隠蔽し、テストでは Fake を注入する。
- `WordDictionary` はプロトコル化し（Swift 標準の `Dictionary` との名前衝突を避ける）、テストでは小さなインメモリ辞書を使う。

## 10. テスト

Swift Testing の Unit テストターゲット `TangomiruTests` を新規追加する。

- `ScoreRule`: nil/-1/0/1/2 × 正誤の全パターン。
- `QuizEngine`: 優先順、出題数（10/20/全問/不足時）、再出題位置、再出題時にスコアが動かないこと。
- `ChoiceBuilder`: 4択の構成、誤答の優先順、重複排除。
- 抽出: 熟語の最長一致優先、熟語内トークンの単語除外、基本語・固有名詞・数字の除外、原形化、出現位置の正しさ（テスト用の小辞書）。
- `ExtractionPipeline`: Fake Enricher で上乗せ反映・チャンク失敗時のフォールバック・実在しない熟語の破棄。
- Foundation Models の生成品質は実機での手動確認とする。

## 11. スコープ外（YAGNI）

- 日本語 → 英語の逆方向クイズ
- 間隔反復（SRS）
- 文単位の和訳
- iCloud 同期、複数端末共有
