# Tangomiru 実装計画

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** コピペした英文から単語・熟語を抽出し、4択クイズで覚え、読解モードで元の英文を読めるようになる iOS アプリを作る。

**Architecture:** 抽出は全端末共通の「NaturalLanguage によるトークン化 + 同梱 EJDict 辞書照合」を土台にし、Foundation Models が使える端末だけ文脈訳・誤答・熟語を上乗せする（失敗時は辞書結果にフォールバック）。ドメインロジック（スコア、出題、選択肢、抽出、読解ハイライト分割）は UI 非依存の `nonisolated` 値型に置いて Swift Testing で単体テストし、SwiftUI 画面と SwiftData モデルはその上に薄く載せる。

**Tech Stack:** Swift 5 モード（Xcode 26.3）/ SwiftUI / SwiftData / NaturalLanguage / FoundationModels / Swift Testing / iOS 26.2

**Spec:** `docs/superpowers/specs/2026-09-30-tangomiru-design.md`

## Global Constraints

- デプロイターゲット: iOS 26.2（既存設定のまま）。外部ライブラリ（SPM 等）は追加しない。
- プロジェクト設定 `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` のため、ドメイン／抽出の型は必ず `nonisolated` を付ける。重い処理（抽出）は `@concurrent` でメインスレッド外に出す。
- `SWIFT_UPCOMING_FEATURE_MEMBER_IMPORT_VISIBILITY = YES` のため、Foundation の API を使うファイル（テスト含む）は `import Foundation` を明示する。
- Xcode プロジェクトは File System Synchronized Group。`Tangomiru/` と `TangomiruTests/` 配下にファイルを置けば自動でターゲットに入る（pbxproj の編集不要）。`.tsv` / `.txt` も自動でバンドルリソースになる。
- スコア: `nil`=未学習, `-1`=超苦手, `0`=苦手, `1`=うろ覚え, `2`=覚えた。初回は正解→1／不正解→0、以降 ±1（範囲 −1〜2）。
- 出題優先順: 超苦手 → 苦手 → 未学習 → うろ覚え → 覚えた（同じ状態内はランダム）。
- 出題数: 10問 / 20問 / 全問（初期値10問、`@AppStorage("quizLength")` で保持）。
- 間違えた語は同じ回の3問後に再出題（出題数に数えない、スコアは各語の初回解答でのみ更新）。
- 本文の上限は 10,000 文字。AI への依頼は 15 語ずつのチャンク。
- 辞書: EJDict（CC0）`src/a.txt`〜`z.txt` を結合した `Tangomiru/Resources/ejdict.tsv`、基本語: EJDict `frequency/2000.txt` を `Tangomiru/Resources/basic_words.txt`。取得元コミット `9663055d59a8cb1a35078a71db7a09ff39305828`。
- UI 文言は日本語。
- テスト実行コマンド（以降 `TEST` と表記）:
  `xcodebuild test -project Tangomiru.xcodeproj -scheme Tangomiru -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData 2>&1 | grep -E "error:|passed|failed|TEST SUCCEEDED|TEST FAILED"`
  特定スイートだけ: 末尾の `2>&1` の前に `-only-testing:TangomiruTests/<SuiteName>` を付ける。
- ビルドコマンド（以降 `BUILD`）:
  `xcodebuild build -project Tangomiru.xcodeproj -scheme Tangomiru -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build/DerivedData 2>&1 | grep -E "error:|BUILD SUCCEEDED|BUILD FAILED"`

## Review Focus

1. **絵文字・スマートクォート入りの英文** — ペーストされた本文に `😀` や `“ ”` が含まれても、ハイライトとクイズの太字位置がずれない（UTF-16 オフセットで一貫させる）。→ Task 6（Tokenizer）と Task 8（TextSearch）と Task 11（ReadingSegmenter）にテストを追加済み。
2. **選択肢ボタンの連打** — 同じ問題に2回解答してもスコアが二重に動かず、再出題も重複しない。→ Task 4 `answeringTwiceCountsOnce`。
3. **語数が少ない英文（誤答候補が足りない）** — 選択肢が4つ未満になっても正解が必ず1つだけ含まれ、重複しない。→ Task 3 `returnsFewerChoicesWhenPoolIsSmall` / `excludesCorrectAnswerAndDuplicates`。
4. **短縮形・所有格（don't / it's / John’s）** — `n't` や `'s` のような断片が出題語にならない。→ Task 7 `rejectsContractionFragments`。
5. **出題ON の語が0件** — クイズ開始ボタンが無効になり、`QuizSession` を作っても即終了扱いでクラッシュしない。→ Task 4 `emptyCardsFinishImmediately`、Task 14 でボタン無効化。

---

## File Structure

```
Tangomiru/
  TangomiruApp.swift                  (modify) ルート: LibraryView + modelContainer + AppServices
  ContentView.swift                   (delete)
  App/AppServices.swift               辞書ロード・パイプライン生成・誤答用ランダム訳
  Domain/SeededRandom.swift           再現可能な乱数（SplitMix64）
  Domain/ScoreRule.swift              スコア更新ルール
  Domain/MasteryState.swift           スコア→状態・表示名・優先順
  Domain/MasteryStats.swift           状態別件数と習得率
  Domain/TextSpan.swift               UTF-16 の位置と長さ
  Domain/PassageInput.swift           入力検証・タイトル自動生成
  Domain/Quiz/QuizCard.swift          出題用の値型
  Domain/Quiz/QuizLength.swift        10/20/全問
  Domain/Quiz/QuizPlanner.swift       出題語の選択
  Domain/Quiz/ChoiceBuilder.swift     4択の生成
  Domain/Quiz/QuizSession.swift       1回分のクイズ進行（再出題・スコア変化）
  Domain/Reading/ReadingSegmenter.swift 本文をハイライト区間に分割
  Domain/Reading/ReadingLink.swift    読解モードのリンク URL
  Extraction/MeaningFormatter.swift   EJDict の訳を表示用に整形
  Extraction/WordDictionary.swift     辞書プロトコル + EJDictionary
  Extraction/BasicWords.swift         基本語リスト
  Extraction/Tokenizer.swift          NLTagger によるトークン化
  Extraction/ExtractedItem.swift      抽出結果の値型 + ItemSource
  Extraction/DictionaryExtractor.swift 熟語・単語の辞書照合
  Extraction/TextSearch.swift         語境界つき大文字小文字無視検索
  Extraction/VocabEnricher.swift      AI 上乗せのプロトコルと入出力型
  Extraction/ExtractionPipeline.swift 抽出全体（チャンク・マージ・フォールバック）
  Extraction/FoundationModelsEnricher.swift Foundation Models 実装
  Models/Passage.swift                SwiftData: 英文
  Models/VocabItem.swift              SwiftData: 出題語
  Features/Shared/MasteryState+UI.swift 色
  Features/Shared/VocabLabel.swift    語＋意味＋状態バッジ
  Features/Library/LibraryView.swift  ① 一覧
  Features/Input/PassageInputView.swift ② 入力
  Features/Input/ExtractionReviewView.swift ③ 抽出結果確認
  Features/Detail/PassageDetailView.swift ④ 詳細
  Features/Detail/ItemListView.swift  単語一覧（ON/OFF）
  Features/Quiz/ContextHighlighter.swift 例文中の語を太字に
  Features/Quiz/QuizView.swift        ⑤ クイズ
  Features/Quiz/QuizResultView.swift  ⑥ 結果
  Features/Reading/ReadingView.swift  ⑦ 読解モード
  Resources/ejdict.tsv, Resources/basic_words.txt
TangomiruTests/
  Support/QuizFixtures.swift, Support/TestDoubles.swift
  (各スイート) *Tests.swift
docs/superpowers/plans/assets/add_test_target.py   テストターゲット追加スクリプト（検証済み）
.gitignore
```

---

### Task 1: テストターゲット追加 + スコアルールと習得状態

**Files:**
- Run: `docs/superpowers/plans/assets/add_test_target.py`（`Tangomiru.xcodeproj/project.pbxproj` を変更し、`Tangomiru.xcodeproj/xcshareddata/xcschemes/Tangomiru.xcscheme` を作る）
- Create: `.gitignore`
- Create: `Tangomiru/Domain/SeededRandom.swift`, `Tangomiru/Domain/ScoreRule.swift`, `Tangomiru/Domain/MasteryState.swift`
- Test: `TangomiruTests/ScoreRuleTests.swift`, `TangomiruTests/MasteryStateTests.swift`, `TangomiruTests/SeededRandomTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated struct SeededRandom: RandomNumberGenerator, Sendable { init(seed: UInt64); init() }`
  - `nonisolated enum ScoreRule { static let minScore = -1; static let maxScore = 2; static func apply(score: Int?, correct: Bool) -> Int }`
  - `nonisolated enum MasteryState: Int, CaseIterable, Identifiable, Sendable { case veryWeak, weak, unseen, vague, mastered; init(score: Int?); var label: String; var priority: Int; var id: Int; static let displayOrder: [MasteryState] }`

- [ ] **Step 1: テストターゲットと共有スキームを追加し、.gitignore を作る**

```bash
python3 docs/superpowers/plans/assets/add_test_target.py .
mkdir -p TangomiruTests
cat > .gitignore <<'EOF'
build/
DerivedData/
xcuserdata/
*.xcresult
.DS_Store
EOF
```

Expected: `ok` と表示される。

- [ ] **Step 2: 失敗するテストを書く**

`TangomiruTests/ScoreRuleTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct ScoreRuleTests {
    @Test(arguments: [
        (nil, true, 1), (nil, false, 0),
        (-1, true, 0), (-1, false, -1),
        (0, true, 1), (0, false, -1),
        (1, true, 2), (1, false, 0),
        (2, true, 2), (2, false, 1),
    ] as [(Int?, Bool, Int)])
    func apply(score: Int?, correct: Bool, expected: Int) {
        #expect(ScoreRule.apply(score: score, correct: correct) == expected)
    }
}
```

`TangomiruTests/MasteryStateTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct MasteryStateTests {
    @Test(arguments: [
        (nil, MasteryState.unseen), (-1, .veryWeak), (0, .weak), (1, .vague), (2, .mastered),
    ] as [(Int?, MasteryState)])
    func mapsScore(score: Int?, expected: MasteryState) {
        #expect(MasteryState(score: score) == expected)
    }

    @Test func labels() {
        #expect(MasteryState.allCases.map(\.label) == ["超苦手", "苦手", "未学習", "うろ覚え", "覚えた"])
    }

    @Test func priorityFollowsQuizOrder() {
        let sorted = MasteryState.allCases.sorted { $0.priority < $1.priority }
        #expect(sorted == [.veryWeak, .weak, .unseen, .vague, .mastered])
    }

    @Test func displayOrderStartsWithMastered() {
        #expect(MasteryState.displayOrder == [.mastered, .vague, .weak, .veryWeak, .unseen])
    }
}
```

`TangomiruTests/SeededRandomTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct SeededRandomTests {
    @Test func sameSeedGivesSameSequence() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        #expect((0..<5).map { _ in a.next() } == (0..<5).map { _ in b.next() })
    }

    @Test func differentSeedsDiffer() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        #expect(a.next() != b.next())
    }
}
```

- [ ] **Step 3: テストが失敗することを確認**

Run: `TEST`
Expected: `error:` で `cannot find 'ScoreRule' in scope` などのコンパイルエラー。

- [ ] **Step 4: 実装を書く**

`Tangomiru/Domain/SeededRandom.swift`:

```swift
import Foundation

/// SplitMix64。テストで結果を再現できるよう、出題や選択肢のシャッフルは常にこの型を使う。
nonisolated struct SeededRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    init() {
        self.init(seed: UInt64.random(in: .min ... .max))
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }
}
```

`Tangomiru/Domain/ScoreRule.swift`:

```swift
/// 習得スコアの更新ルール。nil=未学習, -1=超苦手, 0=苦手, 1=うろ覚え, 2=覚えた
nonisolated enum ScoreRule {
    static let minScore = -1
    static let maxScore = 2

    static func apply(score: Int?, correct: Bool) -> Int {
        guard let score else { return correct ? 1 : 0 }
        return min(max(score + (correct ? 1 : -1), minScore), maxScore)
    }
}
```

`Tangomiru/Domain/MasteryState.swift`:

```swift
/// rawValue は出題の優先順（小さいほど先に出す）
nonisolated enum MasteryState: Int, CaseIterable, Identifiable, Sendable {
    case veryWeak
    case weak
    case unseen
    case vague
    case mastered

    /// 詳細画面の内訳の並び
    static let displayOrder: [MasteryState] = [.mastered, .vague, .weak, .veryWeak, .unseen]

    init(score: Int?) {
        switch score {
        case .none: self = .unseen
        case .some(let value) where value < 0: self = .veryWeak
        case .some(0): self = .weak
        case .some(1): self = .vague
        case .some: self = .mastered
        }
    }

    var id: Int { rawValue }
    var priority: Int { rawValue }

    var label: String {
        switch self {
        case .veryWeak: "超苦手"
        case .weak: "苦手"
        case .unseen: "未学習"
        case .vague: "うろ覚え"
        case .mastered: "覚えた"
        }
    }
}
```

- [ ] **Step 5: テストが通ることを確認**

Run: `TEST`
Expected: `** TEST SUCCEEDED **`、`ScoreRuleTests` / `MasteryStateTests` / `SeededRandomTests` がすべて passed。

- [ ] **Step 6: コミット**

```bash
git add .gitignore Tangomiru.xcodeproj Tangomiru/Domain TangomiruTests docs/superpowers/plans/assets
git commit -m "Add test target, score rule, and mastery state"
```

---

### Task 2: 出題カードと出題語の選択

**Files:**
- Create: `Tangomiru/Domain/Quiz/QuizCard.swift`, `Tangomiru/Domain/Quiz/QuizLength.swift`, `Tangomiru/Domain/Quiz/QuizPlanner.swift`
- Create: `TangomiruTests/Support/QuizFixtures.swift`
- Test: `TangomiruTests/QuizPlannerTests.swift`

**Interfaces:**
- Consumes: `SeededRandom`, `MasteryState(score:)`, `.priority`
- Produces:
  - `nonisolated struct QuizCard: Identifiable, Hashable, Sendable { let id: UUID; let term: String; let meaning: String; let distractors: [String]; let contextSentence: String; let highlight: String; let score: Int? }`（`highlight` は例文中で太字にする本文上の表記）
  - `nonisolated enum QuizLength: Int, CaseIterable, Identifiable, Sendable { case ten = 10, twenty = 20, all = 0; var limit: Int?; var label: String }`
  - `nonisolated enum QuizPlanner { static func select(from: [QuizCard], length: QuizLength, using: inout SeededRandom) -> [QuizCard] }`
  - テスト用: `nonisolated func makeCard(_ term: String, score: Int?, distractors: [String] = []) -> QuizCard`（meaning は `"\(term)の意味"`）

- [ ] **Step 1: テスト用フィクスチャと失敗するテストを書く**

`TangomiruTests/Support/QuizFixtures.swift`:

```swift
import Foundation
@testable import Tangomiru

nonisolated func makeCard(_ term: String, score: Int?, distractors: [String] = []) -> QuizCard {
    QuizCard(
        id: UUID(),
        term: term,
        meaning: "\(term)の意味",
        distractors: distractors,
        contextSentence: "This is \(term).",
        highlight: term,
        score: score
    )
}
```

`TangomiruTests/QuizPlannerTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct QuizPlannerTests {
    @Test func ordersByPriority() {
        let cards = [
            makeCard("m", score: 2), makeCard("v", score: 1), makeCard("u", score: nil),
            makeCard("w", score: 0), makeCard("vw", score: -1),
        ]
        var rng = SeededRandom(seed: 1)
        let selected = QuizPlanner.select(from: cards, length: .all, using: &rng)
        #expect(selected.map(\.term) == ["vw", "w", "u", "v", "m"])
    }

    @Test(arguments: [(QuizLength.ten, 10), (.twenty, 20), (.all, 25)] as [(QuizLength, Int)])
    func limitsCount(length: QuizLength, expected: Int) {
        let cards = (0..<25).map { makeCard("t\($0)", score: nil) }
        var rng = SeededRandom(seed: 1)
        #expect(QuizPlanner.select(from: cards, length: length, using: &rng).count == expected)
    }

    @Test func returnsAllWhenFewerThanLimit() {
        let cards = (0..<3).map { makeCard("t\($0)", score: nil) }
        var rng = SeededRandom(seed: 1)
        #expect(QuizPlanner.select(from: cards, length: .ten, using: &rng).count == 3)
    }

    @Test func limitPrefersWeakerCards() {
        let mastered = (0..<10).map { makeCard("m\($0)", score: 2) }
        let weak = (0..<5).map { makeCard("w\($0)", score: 0) }
        var rng = SeededRandom(seed: 1)
        let selected = QuizPlanner.select(from: mastered + weak, length: .ten, using: &rng)
        #expect(Set(weak.map(\.id)).isSubset(of: Set(selected.map(\.id))))
    }

    @Test func shufflesWithinSameState() {
        let cards = (0..<10).map { makeCard("t\($0)", score: nil) }
        var rng1 = SeededRandom(seed: 1)
        var rng2 = SeededRandom(seed: 2)
        let a = QuizPlanner.select(from: cards, length: .all, using: &rng1).map(\.term)
        let b = QuizPlanner.select(from: cards, length: .all, using: &rng2).map(\.term)
        #expect(a != b)
        #expect(Set(a) == Set(b))
    }

    @Test func emptyInputReturnsEmpty() {
        var rng = SeededRandom(seed: 1)
        #expect(QuizPlanner.select(from: [], length: .ten, using: &rng).isEmpty)
    }

    @Test func lengthLabels() {
        #expect(QuizLength.allCases.map(\.label) == ["10問", "20問", "全問"])
        #expect(QuizLength.all.limit == nil)
        #expect(QuizLength.twenty.limit == 20)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/QuizPlannerTests`）
Expected: `cannot find 'QuizCard' in scope` などのコンパイルエラー。

- [ ] **Step 3: 実装を書く**

`Tangomiru/Domain/Quiz/QuizCard.swift`:

```swift
import Foundation

/// クイズ1問分の元データ（SwiftData に依存しない値型）
nonisolated struct QuizCard: Identifiable, Hashable, Sendable {
    let id: UUID
    let term: String
    let meaning: String
    /// AI が生成した誤答（辞書モードでは空）
    let distractors: [String]
    let contextSentence: String
    /// 例文中で太字にする表記（本文に出てきた形。例: term が "run" なら "running"）
    let highlight: String
    let score: Int?
}
```

`Tangomiru/Domain/Quiz/QuizLength.swift`:

```swift
nonisolated enum QuizLength: Int, CaseIterable, Identifiable, Sendable {
    case ten = 10
    case twenty = 20
    case all = 0

    var id: Int { rawValue }

    /// nil は全問
    var limit: Int? { self == .all ? nil : rawValue }

    var label: String { self == .all ? "全問" : "\(rawValue)問" }
}
```

`Tangomiru/Domain/Quiz/QuizPlanner.swift`:

```swift
nonisolated enum QuizPlanner {
    /// 超苦手 → 苦手 → 未学習 → うろ覚え → 覚えた の順に並べ、同じ状態内はシャッフルして先頭から取る
    static func select(from cards: [QuizCard], length: QuizLength, using rng: inout SeededRandom) -> [QuizCard] {
        let grouped = Dictionary(grouping: cards) { MasteryState(score: $0.score) }
        var ordered: [QuizCard] = []
        for state in MasteryState.allCases.sorted(by: { $0.priority < $1.priority }) {
            ordered += (grouped[state] ?? []).shuffled(using: &rng)
        }
        guard let limit = length.limit else { return ordered }
        return Array(ordered.prefix(limit))
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/QuizPlannerTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Domain/Quiz TangomiruTests
git commit -m "Add quiz card, length, and planner"
```

---

### Task 3: 4択の選択肢生成

**Files:**
- Create: `Tangomiru/Domain/Quiz/ChoiceBuilder.swift`
- Test: `TangomiruTests/ChoiceBuilderTests.swift`

**Interfaces:**
- Consumes: `QuizCard`, `SeededRandom`, `makeCard`
- Produces: `nonisolated enum ChoiceBuilder { static let choiceCount = 4; static func choices(for: QuizCard, passageMeanings: [String], fallbackMeanings: [String], using: inout SeededRandom) -> [String] }`

- [ ] **Step 1: 失敗するテストを書く**

`TangomiruTests/ChoiceBuilderTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct ChoiceBuilderTests {
    @Test func usesAIDistractorsFirst() {
        let card = makeCard("apple", score: nil, distractors: ["梨", "桃", "柿"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["犬", "猫"], fallbackMeanings: ["空"], using: &rng)
        #expect(Set(choices) == ["appleの意味", "梨", "桃", "柿"])
    }

    @Test func fillsFromPassageBeforeFallback() {
        let card = makeCard("apple", score: nil, distractors: ["梨"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["犬", "猫"], fallbackMeanings: ["空", "海"], using: &rng)
        #expect(Set(choices) == ["appleの意味", "梨", "犬", "猫"])
    }

    @Test func excludesCorrectAnswerAndDuplicates() {
        let card = makeCard("apple", score: nil, distractors: ["appleの意味", "梨", "梨"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(
            for: card, passageMeanings: ["appleの意味", "犬"], fallbackMeanings: ["海", "空"], using: &rng
        )
        #expect(choices.count == 4)
        #expect(Set(choices).count == 4)
        #expect(choices.filter { $0 == "appleの意味" }.count == 1)
        #expect(choices.contains("梨"))
        #expect(choices.contains("犬"))
    }

    @Test func returnsFewerChoicesWhenPoolIsSmall() {
        let card = makeCard("apple", score: nil)
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["appleの意味"], fallbackMeanings: ["犬"], using: &rng)
        #expect(Set(choices) == ["appleの意味", "犬"])
    }

    @Test func correctAnswerPositionVaries() {
        let card = makeCard("apple", score: nil, distractors: ["梨", "桃", "柿"])
        var positions = Set<Int>()
        for seed in 1...20 {
            var rng = SeededRandom(seed: UInt64(seed))
            let choices = ChoiceBuilder.choices(for: card, passageMeanings: [], fallbackMeanings: [], using: &rng)
            positions.insert(choices.firstIndex(of: "appleの意味")!)
        }
        #expect(positions.count > 1)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/ChoiceBuilderTests`）
Expected: `cannot find 'ChoiceBuilder' in scope`

- [ ] **Step 3: 実装を書く**

`Tangomiru/Domain/Quiz/ChoiceBuilder.swift`:

```swift
import Foundation

nonisolated enum ChoiceBuilder {
    static let choiceCount = 4

    /// 正解1つ＋誤答をシャッフルして返す。
    /// 誤答の優先順: AI 生成の誤答 → 同じ英文の別の語の訳 → 辞書のランダムな訳。
    /// 候補が足りない場合は4つ未満になる（正解は必ず1つだけ含む）。
    static func choices(
        for card: QuizCard,
        passageMeanings: [String],
        fallbackMeanings: [String],
        using rng: inout SeededRandom
    ) -> [String] {
        let candidates = card.distractors
            + passageMeanings.shuffled(using: &rng)
            + fallbackMeanings.shuffled(using: &rng)
        var seen: Set<String> = [card.meaning]
        var wrong: [String] = []
        for candidate in candidates where wrong.count < choiceCount - 1 {
            let trimmed = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty, seen.insert(trimmed).inserted else { continue }
            wrong.append(trimmed)
        }
        return ([card.meaning] + wrong).shuffled(using: &rng)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/ChoiceBuilderTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Domain/Quiz/ChoiceBuilder.swift TangomiruTests/ChoiceBuilderTests.swift
git commit -m "Add quiz choice builder"
```

---

### Task 4: クイズ進行（再出題とスコア変化）

**Files:**
- Create: `Tangomiru/Domain/Quiz/QuizSession.swift`
- Test: `TangomiruTests/QuizSessionTests.swift`

**Interfaces:**
- Consumes: `QuizCard`, `QuizLength`, `QuizPlanner.select`, `ChoiceBuilder.choices`, `ScoreRule.apply`, `SeededRandom`
- Produces:
  - `nonisolated struct QuizQuestion: Equatable, Sendable { let card: QuizCard; let choices: [String]; let isRetry: Bool }`
  - `nonisolated struct AnswerFeedback: Equatable, Sendable { let isCorrect: Bool; let correctAnswer: String }`
  - `nonisolated struct ScoreChange: Equatable, Sendable { let cardID: UUID; let term: String; let before: Int?; let after: Int; var isPromotion: Bool; var isDemotion: Bool }`
  - `nonisolated struct QuizSession: Sendable { static let retryGap = 3; init(cards: [QuizCard], length: QuizLength, fallbackMeanings: [String], rng: SeededRandom = SeededRandom()); private(set) var current: QuizQuestion?; private(set) var position: Int; var totalCount: Int; let questionCount: Int; private(set) var correctCount: Int; private(set) var changes: [ScoreChange]; var isFinished: Bool; @discardableResult mutating func answer(_ choice: String) -> AnswerFeedback; mutating func advance() }`

- [ ] **Step 1: 失敗するテストを書く**

`TangomiruTests/QuizSessionTests.swift`:

```swift
import Foundation
import Testing
@testable import Tangomiru

struct QuizSessionTests {
    private func session(_ cards: [QuizCard], length: QuizLength = .all) -> QuizSession {
        QuizSession(cards: cards, length: length, fallbackMeanings: ["空", "海", "山"], rng: SeededRandom(seed: 7))
    }

    @Test func correctFirstAnswerRaisesScore() {
        let card = makeCard("a", score: nil)
        var s = session([card])
        let feedback = s.answer("aの意味")
        #expect(feedback == AnswerFeedback(isCorrect: true, correctAnswer: "aの意味"))
        #expect(s.changes == [ScoreChange(cardID: card.id, term: "a", before: nil, after: 1)])
        s.advance()
        #expect(s.isFinished)
        #expect(s.correctCount == 1)
    }

    @Test func wrongAnswerSchedulesRetryThreeQuestionsLater() {
        let cards = (0..<6).map { makeCard("t\($0)", score: 1) }
        var s = session(cards)
        let first = s.current!.card
        s.answer("wrong")
        s.advance()
        var seen: [QuizQuestion] = []
        while let question = s.current {
            seen.append(question)
            s.answer(question.card.meaning)
            s.advance()
        }
        #expect(seen.count == 6)
        #expect(seen[3].card.id == first.id)
        #expect(seen[3].isRetry)
        #expect(s.totalCount == 7)
    }

    @Test func retryDoesNotChangeScore() {
        var s = session([makeCard("a", score: 2)])
        s.answer("wrong")
        s.advance()
        #expect(s.current?.isRetry == true)
        s.answer("aの意味")
        s.advance()
        #expect(s.isFinished)
        #expect(s.changes.map(\.after) == [1])
        #expect(s.correctCount == 0)
    }

    @Test func retryNearEndIsAppended() {
        var s = session([makeCard("a", score: nil), makeCard("b", score: nil)])
        let firstTerm = s.current!.card.term
        s.answer("\(firstTerm)の意味")
        s.advance()
        s.answer("wrong")
        s.advance()
        #expect(s.current?.isRetry == true)
        #expect(s.totalCount == 3)
    }

    @Test func answeringTwiceCountsOnce() {
        var s = session([makeCard("a", score: nil)])
        s.answer("aの意味")
        let second = s.answer("wrong")
        #expect(second.isCorrect)
        #expect(s.changes.count == 1)
        #expect(s.changes[0].after == 1)
        s.advance()
        #expect(s.isFinished)
    }

    @Test func emptyCardsFinishImmediately() {
        let s = session([])
        #expect(s.isFinished)
        #expect(s.questionCount == 0)
    }

    @Test func respectsLength() {
        let s = session((0..<25).map { makeCard("t\($0)", score: nil) }, length: .ten)
        #expect(s.questionCount == 10)
        #expect(s.totalCount == 10)
    }

    @Test func choicesIncludeCorrectAnswer() {
        let s = session((0..<4).map { makeCard("t\($0)", score: nil) })
        let question = s.current!
        #expect(question.choices.count == 4)
        #expect(question.choices.contains(question.card.meaning))
    }

    @Test(arguments: [
        (nil, 1, true, false), (nil, 0, false, true), (2, 1, false, true),
        (0, 1, true, false), (-1, -1, false, false), (2, 2, false, false),
    ] as [(Int?, Int, Bool, Bool)])
    func changeDirection(before: Int?, after: Int, promotion: Bool, demotion: Bool) {
        let change = ScoreChange(cardID: UUID(), term: "x", before: before, after: after)
        #expect(change.isPromotion == promotion)
        #expect(change.isDemotion == demotion)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/QuizSessionTests`）
Expected: `cannot find 'QuizSession' in scope`

- [ ] **Step 3: 実装を書く**

`Tangomiru/Domain/Quiz/QuizSession.swift`:

```swift
import Foundation

nonisolated struct QuizQuestion: Equatable, Sendable {
    let card: QuizCard
    let choices: [String]
    /// 間違えた語の再出題（スコアは動かない）
    let isRetry: Bool
}

nonisolated struct AnswerFeedback: Equatable, Sendable {
    let isCorrect: Bool
    let correctAnswer: String
}

nonisolated struct ScoreChange: Equatable, Sendable {
    let cardID: UUID
    let term: String
    let before: Int?
    let after: Int

    /// 未学習(nil)は苦手(0)とうろ覚え(1)の間として比べる
    private var beforeLevel: Double { before.map(Double.init) ?? 0.5 }
    var isPromotion: Bool { Double(after) > beforeLevel }
    var isDemotion: Bool { Double(after) < beforeLevel }
}

/// 1回分のクイズ。出題順・再出題・スコア変化を管理する（保存は呼び出し側が changes を反映する）
nonisolated struct QuizSession: Sendable {
    static let retryGap = 3

    private struct Entry: Sendable {
        let card: QuizCard
        let isRetry: Bool
    }

    private var queue: [Entry]
    private var rng: SeededRandom
    private let passageMeanings: [String]
    private let fallbackMeanings: [String]
    private var lastFeedback: AnswerFeedback?

    private(set) var current: QuizQuestion?
    private(set) var position = 0
    /// 初回出題の問題数（再出題を含まない）
    let questionCount: Int
    /// 初回解答で正解した数
    private(set) var correctCount = 0
    /// 初回解答によるスコア変化（解答順）
    private(set) var changes: [ScoreChange] = []

    init(cards: [QuizCard], length: QuizLength, fallbackMeanings: [String], rng: SeededRandom = SeededRandom()) {
        var rng = rng
        let selected = QuizPlanner.select(from: cards, length: length, using: &rng)
        self.queue = selected.map { Entry(card: $0, isRetry: false) }
        self.rng = rng
        self.passageMeanings = cards.map(\.meaning)
        self.fallbackMeanings = fallbackMeanings
        self.questionCount = selected.count
        self.current = nil
        self.current = makeQuestion(at: 0)
    }

    /// 再出題を含む現在の総問題数
    var totalCount: Int { queue.count }
    var isFinished: Bool { current == nil }

    @discardableResult
    mutating func answer(_ choice: String) -> AnswerFeedback {
        guard current != nil else { return AnswerFeedback(isCorrect: false, correctAnswer: "") }
        if let lastFeedback { return lastFeedback }
        let entry = queue[position]
        let isCorrect = choice == entry.card.meaning
        if !entry.isRetry {
            let after = ScoreRule.apply(score: entry.card.score, correct: isCorrect)
            changes.append(ScoreChange(cardID: entry.card.id, term: entry.card.term, before: entry.card.score, after: after))
            if isCorrect { correctCount += 1 }
        }
        if !isCorrect {
            let retryIndex = min(position + 1 + Self.retryGap, queue.count)
            queue.insert(Entry(card: entry.card, isRetry: true), at: retryIndex)
        }
        let feedback = AnswerFeedback(isCorrect: isCorrect, correctAnswer: entry.card.meaning)
        lastFeedback = feedback
        return feedback
    }

    mutating func advance() {
        guard current != nil else { return }
        lastFeedback = nil
        position += 1
        current = makeQuestion(at: position)
    }

    private mutating func makeQuestion(at index: Int) -> QuizQuestion? {
        guard queue.indices.contains(index) else { return nil }
        let entry = queue[index]
        let choices = ChoiceBuilder.choices(
            for: entry.card,
            passageMeanings: passageMeanings,
            fallbackMeanings: fallbackMeanings,
            using: &rng
        )
        return QuizQuestion(card: entry.card, choices: choices, isRetry: entry.isRetry)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/QuizSessionTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Domain/Quiz/QuizSession.swift TangomiruTests/QuizSessionTests.swift
git commit -m "Add quiz session with retries and score changes"
```

---

### Task 5: 辞書データと基本語リスト

**Files:**
- Create: `Tangomiru/Resources/ejdict.tsv`, `Tangomiru/Resources/basic_words.txt`（ダウンロード）
- Create: `Tangomiru/Extraction/MeaningFormatter.swift`, `Tangomiru/Extraction/WordDictionary.swift`, `Tangomiru/Extraction/BasicWords.swift`
- Test: `TangomiruTests/MeaningFormatterTests.swift`, `TangomiruTests/EJDictionaryTests.swift`, `TangomiruTests/BasicWordsTests.swift`

**Interfaces:**
- Consumes: `SeededRandom`
- Produces:
  - `nonisolated protocol WordDictionary: Sendable { func meaning(for key: String) -> String?; func randomMeanings(count: Int, using rng: inout SeededRandom) -> [String] }`（key は小文字。熟語は半角スペース区切り）
  - `nonisolated struct EJDictionary: WordDictionary { init(tsv: String); static func loadBundled(bundle: Bundle = .main) throws -> EJDictionary; var count: Int }`
  - `nonisolated enum ResourceError: Error, Equatable { case missing(String) }`
  - `nonisolated enum MeaningFormatter { static let maxSenses = 2; static func format(_ raw: String) -> String; static func clean(_ sense: String) -> String }`
  - `nonisolated enum BasicWords { static func parse(_ text: String) -> Set<String>; static func loadBundled(bundle: Bundle = .main) throws -> Set<String> }`

- [ ] **Step 1: 辞書データをダウンロードする**

```bash
mkdir -p Tangomiru/Resources
REV=9663055d59a8cb1a35078a71db7a09ff39305828
: > Tangomiru/Resources/ejdict.tsv
for l in {a..z}; do { curl -fsSL "https://raw.githubusercontent.com/kujirahand/EJDict/$REV/src/$l.txt"; echo; } >> Tangomiru/Resources/ejdict.tsv; done
curl -fsSL "https://raw.githubusercontent.com/kujirahand/EJDict/$REV/frequency/2000.txt" -o Tangomiru/Resources/basic_words.txt
wc -l Tangomiru/Resources/ejdict.tsv Tangomiru/Resources/basic_words.txt
```

Expected: ejdict.tsv が約 45,000 行、basic_words.txt が 2,000 行。

- [ ] **Step 2: 失敗するテストを書く**

`TangomiruTests/MeaningFormatterTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct MeaningFormatterTests {
    @Test func keepsFirstTwoSensesAndStripsMarkup() {
        let raw = "『走る』,駆ける / 〈人が〉(…に)『急ぐ』,突進する《+『for』(『to』)+『名』》 / 〈C〉『走ること』"
        #expect(MeaningFormatter.format(raw) == "走る,駆ける / 〈人が〉(…に)急ぐ,突進する")
    }

    @Test func removesCountabilityTags() {
        #expect(MeaningFormatter.clean("〈C〉『走ること』,駆け足;〈U〉走力") == "走ること,駆け足;走力")
    }

    @Test func dropsEmptyAndDuplicateSenses() {
        #expect(MeaningFormatter.format("《米》 / 猫 / 猫 / 犬") == "猫 / 犬")
    }

    @Test func emptyInputGivesEmpty() {
        #expect(MeaningFormatter.format("") == "")
    }
}
```

`TangomiruTests/EJDictionaryTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct EJDictionaryTests {
    let dictionary = EJDictionary(tsv: """
    run\t『走る』,駆ける / 〈人が〉(…に)『急ぐ』,突進する《+『for』(『to』)+『名』》 / 〈C〉『走ること』
    A,a,an\tanswer / ampere
    Polish\tポーランドの
    polish\t…を磨く
    ice cream\tアイスクリーム
    broken line without tab
    """)

    @Test func formatsMeaning() {
        #expect(dictionary.meaning(for: "run") == "走る,駆ける / 〈人が〉(…に)急ぐ,突進する")
    }

    @Test func splitsCommaSeparatedHeadwords() {
        #expect(dictionary.meaning(for: "an") == "answer / ampere")
        #expect(dictionary.meaning(for: "a") == "answer / ampere")
    }

    @Test func prefersLowercaseHeadword() {
        #expect(dictionary.meaning(for: "polish") == "…を磨く")
    }

    @Test func supportsPhrases() {
        #expect(dictionary.meaning(for: "ice cream") == "アイスクリーム")
    }

    @Test func ignoresMalformedLinesAndUnknownWords() {
        #expect(dictionary.count == 5)
        #expect(dictionary.meaning(for: "zzz") == nil)
    }

    @Test func randomMeaningsAreSingleWordsAndUnique() {
        var rng = SeededRandom(seed: 3)
        let meanings = dictionary.randomMeanings(count: 3, using: &rng)
        #expect(!meanings.isEmpty)
        #expect(!meanings.contains("アイスクリーム"))
        #expect(Set(meanings).count == meanings.count)
    }

    @Test func loadsBundledDictionary() throws {
        let bundled = try EJDictionary.loadBundled()
        #expect(bundled.count > 40_000)
        #expect(bundled.meaning(for: "ubiquitous") != nil)
    }
}
```

`TangomiruTests/BasicWordsTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct BasicWordsTests {
    @Test func parseTrimsAndLowercases() {
        #expect(BasicWords.parse(" The\nI\n\nrun \n") == ["the", "i", "run"])
    }

    @Test func loadsBundledList() throws {
        let words = try BasicWords.loadBundled()
        #expect(words.count > 1_900)
        #expect(words.contains("the"))
        #expect(words.contains("run"))
        #expect(!words.contains("ubiquitous"))
    }
}
```

- [ ] **Step 3: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/EJDictionaryTests`）
Expected: `cannot find 'EJDictionary' in scope`

- [ ] **Step 4: 実装を書く**

`Tangomiru/Extraction/MeaningFormatter.swift`:

```swift
import Foundation

/// EJDict の訳（" / " 区切り、『』強調、《》注記、〈C〉〈U〉タグ付き）を表示用に整える
nonisolated enum MeaningFormatter {
    static let maxSenses = 2

    static func format(_ raw: String) -> String {
        var senses: [String] = []
        for sense in raw.components(separatedBy: " / ") {
            let cleaned = clean(sense)
            if !cleaned.isEmpty && !senses.contains(cleaned) {
                senses.append(cleaned)
            }
            if senses.count == maxSenses { break }
        }
        return senses.joined(separator: " / ")
    }

    static func clean(_ sense: String) -> String {
        var result = ""
        var annotationDepth = 0
        for character in sense {
            switch character {
            case "《": annotationDepth += 1
            case "》": annotationDepth = max(0, annotationDepth - 1)
            case "『", "』": continue
            default:
                if annotationDepth == 0 { result.append(character) }
            }
        }
        for tag in ["〈C〉", "〈U〉"] {
            result = result.replacingOccurrences(of: tag, with: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
```

`Tangomiru/Extraction/WordDictionary.swift`:

```swift
import Foundation

nonisolated protocol WordDictionary: Sendable {
    /// 小文字の見出し語（熟語は半角スペース区切り）で引き、表示用に整形した訳を返す
    func meaning(for key: String) -> String?
    /// 誤答の補充用に、単語（熟語以外）の訳をランダムに返す
    func randomMeanings(count: Int, using rng: inout SeededRandom) -> [String]
}

nonisolated enum ResourceError: Error, Equatable {
    case missing(String)
}

nonisolated struct EJDictionary: WordDictionary {
    /// 小文字見出し → EJDict の生の訳（整形は引くときに行う）
    private let rawEntries: [String: String]
    private let keys: [String]

    init(tsv: String) {
        var entries: [String: String] = [:]
        var lowercaseHeadwords: Set<String> = []
        for line in tsv.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let raw = String(parts[1])
            for headword in parts[0].split(separator: ",") {
                let head = headword.trimmingCharacters(in: .whitespaces)
                guard !head.isEmpty else { continue }
                let key = head.lowercased()
                let isLowercase = head == key
                // "Polish" と "polish" のように大文字違いがある場合は小文字の見出しを優先する
                if entries[key] != nil && (lowercaseHeadwords.contains(key) || !isLowercase) { continue }
                entries[key] = raw
                if isLowercase { lowercaseHeadwords.insert(key) }
            }
        }
        rawEntries = entries
        keys = entries.keys.sorted()
    }

    static func loadBundled(bundle: Bundle = .main) throws -> EJDictionary {
        guard let url = bundle.url(forResource: "ejdict", withExtension: "tsv") else {
            throw ResourceError.missing("ejdict.tsv")
        }
        return EJDictionary(tsv: try String(contentsOf: url, encoding: .utf8))
    }

    var count: Int { rawEntries.count }

    func meaning(for key: String) -> String? {
        guard let raw = rawEntries[key] else { return nil }
        let formatted = MeaningFormatter.format(raw)
        return formatted.isEmpty ? nil : formatted
    }

    func randomMeanings(count: Int, using rng: inout SeededRandom) -> [String] {
        guard !keys.isEmpty else { return [] }
        var result: [String] = []
        var attempts = 0
        while result.count < count && attempts < count * 10 {
            attempts += 1
            let key = keys[Int.random(in: 0..<keys.count, using: &rng)]
            guard !key.contains(" "), let meaning = meaning(for: key), !result.contains(meaning) else { continue }
            result.append(meaning)
        }
        return result
    }
}
```

`Tangomiru/Extraction/BasicWords.swift`:

```swift
import Foundation

/// 出題から除外する基本語（EJDict frequency/2000.txt）
nonisolated enum BasicWords {
    static func parse(_ text: String) -> Set<String> {
        Set(
            text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    static func loadBundled(bundle: Bundle = .main) throws -> Set<String> {
        guard let url = bundle.url(forResource: "basic_words", withExtension: "txt") else {
            throw ResourceError.missing("basic_words.txt")
        }
        return parse(try String(contentsOf: url, encoding: .utf8))
    }
}
```

- [ ] **Step 5: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/MeaningFormatterTests -only-testing:TangomiruTests/EJDictionaryTests -only-testing:TangomiruTests/BasicWordsTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 6: コミット**

```bash
git add Tangomiru/Resources Tangomiru/Extraction TangomiruTests
git commit -m "Add bundled EJDict dictionary and basic word list"
```

---

### Task 6: トークン化（NaturalLanguage）

**Files:**
- Create: `Tangomiru/Domain/TextSpan.swift`, `Tangomiru/Extraction/Tokenizer.swift`
- Test: `TangomiruTests/TokenizerTests.swift`

**Interfaces:**
- Produces:
  - `nonisolated struct TextSpan: Codable, Hashable, Sendable { var location: Int; var length: Int; var end: Int; func overlaps(_ other: TextSpan) -> Bool }`（UTF-16 単位。`NSRange` と同じ）
  - `nonisolated struct Token: Equatable, Sendable { let surface: String; let lemma: String; let span: TextSpan; let sentenceIndex: Int; let isProperNoun: Bool; let followsPreviousDirectly: Bool }`（`lemma` は小文字。取れなければ表層形の小文字。`followsPreviousDirectly` は直前トークンとの間が空白だけなら true）
  - `nonisolated struct TokenizedText: Equatable, Sendable { let tokens: [Token]; let sentences: [String] }`
  - `nonisolated struct Tokenizer: Sendable { func tokenize(_ text: String) -> TokenizedText }`

- [ ] **Step 1: 失敗するテストを書く**

`TangomiruTests/TokenizerTests.swift`:

```swift
import Foundation
import Testing
@testable import Tangomiru

struct TokenizerTests {
    let tokenizer = Tokenizer()

    private func token(_ surface: String, in result: TokenizedText) -> Token? {
        result.tokens.first { $0.surface == surface }
    }

    @Test func lemmatizesInflectedWords() {
        let result = tokenizer.tokenize("She was running and the children ate apples.")
        #expect(token("running", in: result)?.lemma == "run")
        #expect(token("children", in: result)?.lemma == "child")
        #expect(token("ate", in: result)?.lemma == "eat")
        #expect(token("She", in: result)?.lemma == "she")
    }

    @Test func marksProperNouns() {
        let result = tokenizer.tokenize("I met John Smith in Tokyo yesterday.")
        #expect(token("Tokyo", in: result)?.isProperNoun == true)
        #expect(token("Smith", in: result)?.isProperNoun == true)
        #expect(token("met", in: result)?.isProperNoun == false)
    }

    @Test func spansPointToSurfaceInUTF16() {
        let text = "😀 “Café” is ubiquitous."
        let result = tokenizer.tokenize(text)
        let ns = text as NSString
        #expect(!result.tokens.isEmpty)
        for token in result.tokens {
            #expect(ns.substring(with: NSRange(location: token.span.location, length: token.span.length)) == token.surface)
        }
        #expect(token("ubiquitous", in: result)?.span.location == 13)
    }

    @Test func assignsSentenceIndexes() {
        let result = tokenizer.tokenize("I like cats. Dogs are loyal.")
        #expect(result.sentences == ["I like cats.", "Dogs are loyal."])
        #expect(token("cats", in: result)?.sentenceIndex == 0)
        #expect(token("Dogs", in: result)?.sentenceIndex == 1)
    }

    @Test func tracksPunctuationBetweenTokens() {
        #expect(token("cream", in: tokenizer.tokenize("ice cream"))?.followsPreviousDirectly == true)
        #expect(token("cream", in: tokenizer.tokenize("ice, cream"))?.followsPreviousDirectly == false)
        #expect(tokenizer.tokenize("ice cream").tokens.first?.followsPreviousDirectly == false)
    }

    @Test func omitsPunctuationAndWhitespace() {
        let result = tokenizer.tokenize("Hello, world!")
        #expect(result.tokens.map(\.surface) == ["Hello", "world"])
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/TokenizerTests`）
Expected: `cannot find 'Tokenizer' in scope`

- [ ] **Step 3: 実装を書く**

`Tangomiru/Domain/TextSpan.swift`:

```swift
/// 本文中の位置（UTF-16 単位。NSRange と同じ）
nonisolated struct TextSpan: Codable, Hashable, Sendable {
    var location: Int
    var length: Int

    var end: Int { location + length }

    func overlaps(_ other: TextSpan) -> Bool {
        location < other.end && other.location < end
    }
}
```

`Tangomiru/Extraction/Tokenizer.swift`:

```swift
import Foundation
import NaturalLanguage

nonisolated struct Token: Equatable, Sendable {
    let surface: String
    /// 小文字の原形。取れない場合は表層形の小文字
    let lemma: String
    let span: TextSpan
    let sentenceIndex: Int
    let isProperNoun: Bool
    /// 直前のトークンとの間が空白だけなら true（熟語照合で句読点をまたがないため）
    let followsPreviousDirectly: Bool
}

nonisolated struct TokenizedText: Equatable, Sendable {
    let tokens: [Token]
    let sentences: [String]
}

nonisolated struct Tokenizer: Sendable {
    private static let nameTags: Set<NLTag> = [.personalName, .placeName, .organizationName]

    func tokenize(_ text: String) -> TokenizedText {
        let fullRange = text.startIndex..<text.endIndex

        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        let sentenceRanges = sentenceTokenizer.tokens(for: fullRange)
        let sentences = sentenceRanges.map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }

        let tagger = NLTagger(tagSchemes: [.lemma, .nameType])
        tagger.string = text
        var tokens: [Token] = []
        var sentenceIndex = 0
        var previousEnd: String.Index?

        tagger.enumerateTags(
            in: fullRange, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            while sentenceIndex + 1 < sentenceRanges.count && sentenceRanges[sentenceIndex].upperBound <= range.lowerBound {
                sentenceIndex += 1
            }
            let surface = String(text[range])
            let lemma = tag.map { $0.rawValue.lowercased() }.flatMap { $0.isEmpty ? nil : $0 } ?? surface.lowercased()
            let (nameTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .nameType)
            let followsPrevious = previousEnd.map { text[$0..<range.lowerBound].allSatisfy(\.isWhitespace) } ?? false
            let nsRange = NSRange(range, in: text)
            tokens.append(Token(
                surface: surface,
                lemma: lemma,
                span: TextSpan(location: nsRange.location, length: nsRange.length),
                sentenceIndex: sentenceIndex,
                isProperNoun: nameTag.map { Self.nameTags.contains($0) } ?? false,
                followsPreviousDirectly: followsPrevious
            ))
            previousEnd = range.upperBound
            return true
        }
        return TokenizedText(tokens: tokens, sentences: sentences)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/TokenizerTests`）
Expected: `** TEST SUCCEEDED **`。`ubiquitous` の位置 13 は UTF-16 で `😀`(2) + 空白(1) + `“Café”`(6) + 空白(1) + `is`(2) + 空白(1) の合計。

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Domain/TextSpan.swift Tangomiru/Extraction/Tokenizer.swift TangomiruTests/TokenizerTests.swift
git commit -m "Add NaturalLanguage tokenizer"
```

---

### Task 7: 辞書照合による抽出

**Files:**
- Create: `Tangomiru/Extraction/ExtractedItem.swift`, `Tangomiru/Extraction/DictionaryExtractor.swift`
- Create: `TangomiruTests/Support/TestDoubles.swift`
- Test: `TangomiruTests/DictionaryExtractorTests.swift`

**Interfaces:**
- Consumes: `WordDictionary`, `Token`, `TokenizedText`, `TextSpan`
- Produces:
  - `nonisolated enum ItemSource: String, Codable, Hashable, Sendable { case dictionary, ai }`
  - `nonisolated struct ExtractedItem: Hashable, Sendable { var term: String; var meaning: String; var distractors: [String]; var contextSentence: String; var occurrences: [TextSpan]; var source: ItemSource; var firstLocation: Int }`
  - `nonisolated struct DictionaryExtractor: Sendable { static let maxPhraseLength = 4; let dictionary: any WordDictionary; let basicWords: Set<String>; func extract(from: TokenizedText) -> [ExtractedItem]; static func phraseKeys(for: [Token]) -> [String]; static func isWordLike(_: String) -> Bool }`（結果は最初の出現位置順）
  - テスト用: `FakeDictionary(entries: [String: String])`、`tokenized(_ specs: [String], sentences: [String] = ["context"]) -> TokenizedText`

- [ ] **Step 1: テストダブルと失敗するテストを書く**

`TangomiruTests/Support/TestDoubles.swift`:

```swift
import Foundation
@testable import Tangomiru

nonisolated struct FakeDictionary: WordDictionary {
    var entries: [String: String]

    func meaning(for key: String) -> String? { entries[key] }

    func randomMeanings(count: Int, using rng: inout SeededRandom) -> [String] {
        Array(entries.values.sorted().prefix(count))
    }
}

/// トークン列を手で組み立てる。
/// "ran/run" は原形指定、"Tokyo*" は固有名詞、"," は句読点（次の語は直結しない）、"." は文の区切り。
nonisolated func tokenized(_ specs: [String], sentences: [String] = ["context"]) -> TokenizedText {
    var tokens: [Token] = []
    var location = 0
    var sentence = 0
    var afterBreak = true
    for spec in specs {
        if spec == "," || spec == "." {
            if spec == "." { sentence += 1 }
            afterBreak = true
            location += 2
            continue
        }
        var text = spec
        let isProper = text.hasSuffix("*")
        if isProper { text.removeLast() }
        let parts = text.split(separator: "/", maxSplits: 1).map(String.init)
        let surface = parts[0]
        let lemma = parts.count > 1 ? parts[1] : surface.lowercased()
        let length = (surface as NSString).length
        tokens.append(Token(
            surface: surface,
            lemma: lemma,
            span: TextSpan(location: location, length: length),
            sentenceIndex: sentence,
            isProperNoun: isProper,
            followsPreviousDirectly: !afterBreak
        ))
        location += length + 1
        afterBreak = false
    }
    return TokenizedText(tokens: tokens, sentences: sentences)
}
```

`TangomiruTests/DictionaryExtractorTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct DictionaryExtractorTests {
    let dictionary = FakeDictionary(entries: [
        "ice cream": "アイスクリーム", "ice cream soda": "クリームソーダ",
        "ice": "氷", "cream": "クリーム", "soda": "ソーダ",
        "run": "走る", "grant": "許可する", "for granted": "当然のこととして",
        "ubiquitous": "至る所にある", "tokyo": "東京", "apple": "りんご", "the": "その", "n't": "否定",
    ])

    private func extract(_ specs: [String], sentences: [String] = ["context"], basic: Set<String> = ["the"]) -> [ExtractedItem] {
        DictionaryExtractor(dictionary: dictionary, basicWords: basic).extract(from: tokenized(specs, sentences: sentences))
    }

    @Test func prefersLongestPhrase() {
        #expect(extract(["ice", "cream", "soda"]).map(\.term) == ["ice cream soda"])
    }

    @Test func phraseTokensAreNotExtractedAsWords() {
        let items = extract(["ice", "cream"])
        #expect(items.map(\.term) == ["ice cream"])
        #expect(items[0].occurrences == [TextSpan(location: 0, length: 9)])
    }

    @Test func phraseDoesNotSpanPunctuation() {
        #expect(extract(["ice", ",", "cream"]).map(\.term) == ["ice", "cream"])
    }

    @Test func phraseDoesNotSpanSentences() {
        let items = extract(["ice", ".", "cream"], sentences: ["s0", "s1"])
        #expect(items.map(\.term) == ["ice", "cream"])
        #expect(items[1].contextSentence == "s1")
    }

    @Test func matchesPhraseUsingSurfaceForm() {
        #expect(extract(["for", "granted/grant"]).map(\.term) == ["for granted"])
    }

    @Test func usesLemmaForWords() {
        let items = extract(["ran/run"])
        #expect(items.map(\.term) == ["run"])
        #expect(items[0].meaning == "走る")
        #expect(items[0].source == .dictionary)
    }

    @Test func excludesBasicProperNounsNumbersAndUnknown() {
        #expect(extract(["the", "Tokyo*", "2020", "zzzz", "ubiquitous"]).map(\.term) == ["ubiquitous"])
    }

    @Test func excludesByBasicWordLemma() {
        #expect(extract(["running/run"], basic: ["run"]).isEmpty)
    }

    @Test func mergesDuplicatesKeepingFirstContext() {
        let items = extract(["Apple/apple", ".", "apple"], sentences: ["first", "second"])
        #expect(items.count == 1)
        #expect(items[0].occurrences.count == 2)
        #expect(items[0].contextSentence == "first")
    }

    @Test func sortsByFirstOccurrence() {
        #expect(extract(["ubiquitous", ",", "ice", "cream"]).map(\.term) == ["ubiquitous", "ice cream"])
    }

    @Test func rejectsContractionFragments() {
        #expect(extract(["do", "n't"]).isEmpty)
        #expect(!DictionaryExtractor.isWordLike("'s"))
        #expect(DictionaryExtractor.isWordLike("well-known"))
    }

    @Test func phraseKeysCombineSurfaceAndLemma() {
        let keys = DictionaryExtractor.phraseKeys(for: tokenized(["took/take", "off"]).tokens)
        #expect(keys == ["took off", "take off"])
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/DictionaryExtractorTests`）
Expected: `cannot find 'DictionaryExtractor' in scope`

- [ ] **Step 3: 実装を書く**

`Tangomiru/Extraction/ExtractedItem.swift`:

```swift
nonisolated enum ItemSource: String, Codable, Hashable, Sendable {
    case dictionary
    case ai
}

/// 抽出結果（保存前の値型）
nonisolated struct ExtractedItem: Hashable, Sendable {
    var term: String
    var meaning: String
    var distractors: [String]
    var contextSentence: String
    var occurrences: [TextSpan]
    var source: ItemSource

    var firstLocation: Int { occurrences.first?.location ?? .max }
}
```

`Tangomiru/Extraction/DictionaryExtractor.swift`:

```swift
import Foundation

/// トークン列を辞書と照合し、熟語（最長一致優先）と単語を抽出する
nonisolated struct DictionaryExtractor: Sendable {
    static let maxPhraseLength = 4

    let dictionary: any WordDictionary
    let basicWords: Set<String>

    private struct Match {
        let term: String
        let meaning: String
        let length: Int
    }

    func extract(from text: TokenizedText) -> [ExtractedItem] {
        let tokens = text.tokens
        var itemsByTerm: [String: ExtractedItem] = [:]

        func record(_ term: String, meaning: String, span: TextSpan, sentenceIndex: Int) {
            if itemsByTerm[term] != nil {
                itemsByTerm[term]?.occurrences.append(span)
                return
            }
            let sentence = text.sentences.indices.contains(sentenceIndex) ? text.sentences[sentenceIndex] : ""
            itemsByTerm[term] = ExtractedItem(
                term: term, meaning: meaning, distractors: [], contextSentence: sentence,
                occurrences: [span], source: .dictionary
            )
        }

        var index = 0
        while index < tokens.count {
            if let match = longestPhrase(startingAt: index, in: tokens) {
                let first = tokens[index]
                let last = tokens[index + match.length - 1]
                let span = TextSpan(location: first.span.location, length: last.span.end - first.span.location)
                record(match.term, meaning: match.meaning, span: span, sentenceIndex: first.sentenceIndex)
                index += match.length
                continue
            }
            if let match = wordMatch(for: tokens[index]) {
                record(match.term, meaning: match.meaning, span: tokens[index].span, sentenceIndex: tokens[index].sentenceIndex)
            }
            index += 1
        }
        return itemsByTerm.values.sorted { $0.firstLocation < $1.firstLocation }
    }

    private func longestPhrase(startingAt start: Int, in tokens: [Token]) -> Match? {
        let maxLength = min(Self.maxPhraseLength, tokens.count - start)
        guard maxLength >= 2 else { return nil }
        for length in stride(from: maxLength, through: 2, by: -1) {
            let slice = Array(tokens[start..<start + length])
            let isContiguous = slice.dropFirst().allSatisfy {
                $0.followsPreviousDirectly && $0.sentenceIndex == slice[0].sentenceIndex
            }
            guard isContiguous, !slice.contains(where: \.isProperNoun) else { continue }
            for key in Self.phraseKeys(for: slice) {
                if let meaning = dictionary.meaning(for: key) {
                    return Match(term: key, meaning: meaning, length: length)
                }
            }
        }
        return nil
    }

    private func wordMatch(for token: Token) -> Match? {
        let surface = token.surface.lowercased()
        guard !token.isProperNoun, Self.isWordLike(token.lemma),
              !basicWords.contains(token.lemma), !basicWords.contains(surface) else { return nil }
        for key in [token.lemma, surface] {
            if let meaning = dictionary.meaning(for: key) {
                return Match(term: key, meaning: meaning, length: 1)
            }
        }
        return nil
    }

    /// 各トークンの表層形（小文字）と原形の組み合わせを、表層形優先で列挙する（例: "took off", "take off"）
    static func phraseKeys(for tokens: [Token]) -> [String] {
        var keys: [[String]] = [[]]
        for token in tokens {
            let surface = token.surface.lowercased()
            let forms = surface == token.lemma ? [surface] : [surface, token.lemma]
            keys = keys.flatMap { prefix in forms.map { prefix + [$0] } }
        }
        return keys.map { $0.joined(separator: " ") }
    }

    /// 2文字以上で英字から始まり、英字・ハイフン・アポストロフィのみ（"n't" や "'s" は除外）
    static func isWordLike(_ word: String) -> Bool {
        guard word.count >= 2, let first = word.first, first.isLetter else { return false }
        return word.allSatisfy { $0.isLetter || $0 == "-" || $0 == "'" || $0 == "’" }
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/DictionaryExtractorTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Extraction TangomiruTests
git commit -m "Add dictionary-based word and phrase extractor"
```

---

### Task 8: 抽出パイプライン（AI 上乗せ・チャンク・フォールバック）

**Files:**
- Create: `Tangomiru/Extraction/TextSearch.swift`, `Tangomiru/Extraction/VocabEnricher.swift`, `Tangomiru/Extraction/ExtractionPipeline.swift`
- Modify: `TangomiruTests/Support/TestDoubles.swift`（末尾に FakeEnricher 等を追加）
- Test: `TangomiruTests/TextSearchTests.swift`, `TangomiruTests/ExtractionPipelineTests.swift`

**Interfaces:**
- Consumes: `Tokenizer`, `DictionaryExtractor`, `ExtractedItem`, `TextSpan`, `FakeDictionary`
- Produces:
  - `nonisolated enum TextSearch { static func occurrences(of term: String, in text: String) -> [TextSpan] }`（大文字小文字無視・語境界つき）
  - `nonisolated struct EnrichmentInput: Equatable, Sendable { let term: String; let contextSentence: String; let dictionaryMeaning: String }`
  - `nonisolated struct EnrichedEntry: Equatable, Sendable { let term: String; let meaning: String; let distractors: [String] }`
  - `nonisolated struct EnrichmentOutput: Equatable, Sendable { var words: [EnrichedEntry]; var idioms: [EnrichedEntry] }`
  - `nonisolated protocol VocabEnricher: Sendable { var isAvailable: Bool { get }; func enrich(_ inputs: [EnrichmentInput], sentences: [String]) async throws -> EnrichmentOutput }`
  - `nonisolated struct ExtractionResult: Hashable, Sendable { let items: [ExtractedItem]; let usedAI: Bool }`
  - `nonisolated struct ExtractionPipeline: Sendable { static let chunkSize = 15; init(extractor: DictionaryExtractor, enricher: (any VocabEnricher)?); @concurrent func run(_ body: String) async -> ExtractionResult }`

- [ ] **Step 1: テストダブルを追加し、失敗するテストを書く**

`TangomiruTests/Support/TestDoubles.swift` の末尾に追加（ファイル先頭に `import Synchronization` も追加）:

```swift
nonisolated struct FakeError: Error {}

nonisolated struct FakeEnricher: VocabEnricher {
    var isAvailable = true
    let handler: @Sendable ([EnrichmentInput], [String]) throws -> EnrichmentOutput

    func enrich(_ inputs: [EnrichmentInput], sentences: [String]) async throws -> EnrichmentOutput {
        try handler(inputs, sentences)
    }
}

nonisolated final class CallRecorder: Sendable {
    private let storage = Mutex<[[String]]>([])

    func record(_ terms: [String]) {
        storage.withLock { $0.append(terms) }
    }

    var calls: [[String]] { storage.withLock { $0 } }
}
```

`TangomiruTests/TextSearchTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct TextSearchTests {
    @Test func findsAllCaseInsensitiveMatches() {
        #expect(TextSearch.occurrences(of: "give up", in: "Give up? Never give up.") == [
            TextSpan(location: 0, length: 7), TextSpan(location: 15, length: 7),
        ])
    }

    @Test func respectsWordBoundaries() {
        #expect(TextSearch.occurrences(of: "give up", in: "forgive upstairs").isEmpty)
    }

    @Test func usesUTF16OffsetsAfterEmoji() {
        #expect(TextSearch.occurrences(of: "give up", in: "😀 give up") == [TextSpan(location: 3, length: 7)])
    }

    @Test func emptyTermFindsNothing() {
        #expect(TextSearch.occurrences(of: "", in: "abc").isEmpty)
    }
}
```

`TangomiruTests/ExtractionPipelineTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct ExtractionPipelineTests {
    static let words = [
        "abyss", "ballad", "cactus", "dagger", "ember", "falcon", "glacier", "hamlet", "iceberg", "jungle",
        "kernel", "lantern", "meadow", "nectar", "orchid", "pebble", "quartz", "riddle", "saddle", "tundra",
    ]
    static let body = "I saw " + words.joined(separator: ", ") + "."

    let dictionary = FakeDictionary(entries: Dictionary(uniqueKeysWithValues: words.map { ($0, "\($0)の辞書訳") }))

    private func pipeline(_ enricher: (any VocabEnricher)?) -> ExtractionPipeline {
        ExtractionPipeline(extractor: DictionaryExtractor(dictionary: dictionary, basicWords: []), enricher: enricher)
    }

    private static func aiOutput(for inputs: [EnrichmentInput]) -> EnrichmentOutput {
        EnrichmentOutput(
            words: inputs.map { EnrichedEntry(term: $0.term, meaning: "\($0.term)の文脈訳", distractors: ["x", "y", "z", "\($0.term)の文脈訳"]) },
            idioms: []
        )
    }

    @Test func withoutEnricherUsesDictionary() async {
        let result = await pipeline(nil).run(Self.body)
        #expect(!result.usedAI)
        #expect(result.items.map(\.term) == Self.words)
        #expect(result.items[0].meaning == "abyssの辞書訳")
    }

    @Test func unavailableEnricherIsNotCalled() async {
        let enricher = FakeEnricher(isAvailable: false) { _, _ in
            Issue.record("unavailable enricher was called")
            return EnrichmentOutput(words: [], idioms: [])
        }
        let result = await pipeline(enricher).run(Self.body)
        #expect(!result.usedAI)
    }

    @Test func appliesAIMeaningsAndDistractors() async {
        let result = await pipeline(FakeEnricher { inputs, _ in Self.aiOutput(for: inputs) }).run(Self.body)
        #expect(result.usedAI)
        #expect(result.items[0].meaning == "abyssの文脈訳")
        #expect(result.items[0].distractors == ["x", "y", "z"])
        #expect(result.items[0].source == .dictionary)
    }

    @Test func splitsIntoChunksOfFifteen() async {
        let recorder = CallRecorder()
        let enricher = FakeEnricher { inputs, sentences in
            recorder.record(inputs.map(\.term))
            #expect(sentences == [Self.body])
            return Self.aiOutput(for: inputs)
        }
        _ = await pipeline(enricher).run(Self.body)
        #expect(recorder.calls.map(\.count) == [15, 5])
    }

    @Test func failedChunkFallsBackToDictionary() async {
        let enricher = FakeEnricher { inputs, _ in
            if inputs.first?.term == "abyss" { throw FakeError() }
            return Self.aiOutput(for: inputs)
        }
        let result = await pipeline(enricher).run(Self.body)
        #expect(result.usedAI)
        #expect(result.items[0].meaning == "abyssの辞書訳")
        #expect(result.items[19].meaning == "tundraの文脈訳")
    }

    @Test func allChunksFailingMeansDictionaryMode() async {
        let result = await pipeline(FakeEnricher { _, _ in throw FakeError() }).run(Self.body)
        #expect(!result.usedAI)
        #expect(result.items.count == 20)
    }

    @Test func addsIdiomsFoundInTextOnly() async {
        let body = "They gave up on the abyss."
        let enricher = FakeEnricher { inputs, _ in
            EnrichmentOutput(words: [], idioms: [
                EnrichedEntry(term: "gave up", meaning: "諦めた", distractors: ["始めた", "諦めた", "続けた"]),
                EnrichedEntry(term: "look forward to", meaning: "楽しみにする", distractors: []),
                EnrichedEntry(term: "Abyss", meaning: "重複", distractors: []),
            ])
        }
        let result = await pipeline(enricher).run(body)
        #expect(result.items.map(\.term) == ["gave up", "abyss"])
        let idiom = result.items[0]
        #expect(idiom.source == .ai)
        #expect(idiom.meaning == "諦めた")
        #expect(idiom.distractors == ["始めた", "続けた"])
        #expect(idiom.occurrences == [TextSpan(location: 5, length: 7)])
        #expect(idiom.contextSentence == body)
        #expect(result.items[1].meaning == "abyssの辞書訳")
    }

    @Test func emptyTextGivesNoItems() async {
        let result = await pipeline(FakeEnricher { inputs, _ in Self.aiOutput(for: inputs) }).run("the a an")
        #expect(result.items.isEmpty)
        #expect(!result.usedAI)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/TextSearchTests -only-testing:TangomiruTests/ExtractionPipelineTests`）
Expected: `cannot find 'TextSearch' in scope` など

- [ ] **Step 3: 実装を書く**

`Tangomiru/Extraction/TextSearch.swift`:

```swift
import Foundation

nonisolated enum TextSearch {
    /// 大文字小文字を無視し、前後が英字でない位置で一致した出現をすべて返す（UTF-16 単位）
    static func occurrences(of term: String, in text: String) -> [TextSpan] {
        guard !term.isEmpty else { return [] }
        let ns = text as NSString
        var result: [TextSpan] = []
        var searchStart = 0
        while searchStart < ns.length {
            let found = ns.range(
                of: term, options: [.caseInsensitive],
                range: NSRange(location: searchStart, length: ns.length - searchStart)
            )
            guard found.location != NSNotFound else { break }
            if isBoundary(ns, at: found.location - 1) && isBoundary(ns, at: found.location + found.length) {
                result.append(TextSpan(location: found.location, length: found.length))
            }
            searchStart = found.location + 1
        }
        return result
    }

    private static func isBoundary(_ ns: NSString, at index: Int) -> Bool {
        guard index >= 0, index < ns.length, let scalar = UnicodeScalar(ns.character(at: index)) else { return true }
        return !CharacterSet.letters.contains(scalar)
    }
}
```

`Tangomiru/Extraction/VocabEnricher.swift`:

```swift
nonisolated struct EnrichmentInput: Equatable, Sendable {
    let term: String
    let contextSentence: String
    let dictionaryMeaning: String
}

nonisolated struct EnrichedEntry: Equatable, Sendable {
    let term: String
    let meaning: String
    let distractors: [String]
}

nonisolated struct EnrichmentOutput: Equatable, Sendable {
    var words: [EnrichedEntry]
    /// 辞書で拾えなかった熟語
    var idioms: [EnrichedEntry]
}

/// 抽出結果に文脈訳・誤答・熟語を上乗せする（Foundation Models 実装とテスト用 Fake を差し替える）
nonisolated protocol VocabEnricher: Sendable {
    var isAvailable: Bool { get }
    func enrich(_ inputs: [EnrichmentInput], sentences: [String]) async throws -> EnrichmentOutput
}
```

`Tangomiru/Extraction/ExtractionPipeline.swift`:

```swift
import Foundation

nonisolated struct ExtractionResult: Hashable, Sendable {
    let items: [ExtractedItem]
    /// 1チャンク以上で AI の上乗せに成功したか
    let usedAI: Bool
}

nonisolated struct ExtractionPipeline: Sendable {
    static let chunkSize = 15
    static let maxDistractors = 3
    static let maxSentenceLength = 300

    let extractor: DictionaryExtractor
    let enricher: (any VocabEnricher)?
    private let tokenizer = Tokenizer()

    init(extractor: DictionaryExtractor, enricher: (any VocabEnricher)?) {
        self.extractor = extractor
        self.enricher = enricher
    }

    @concurrent
    func run(_ body: String) async -> ExtractionResult {
        let tokenized = tokenizer.tokenize(body)
        var items = extractor.extract(from: tokenized)
        guard let enricher, enricher.isAvailable, !items.isEmpty else {
            return ExtractionResult(items: items, usedAI: false)
        }

        var usedAI = false
        var idioms: [EnrichedEntry] = []
        for start in stride(from: 0, to: items.count, by: Self.chunkSize) {
            let range = start..<min(start + Self.chunkSize, items.count)
            let inputs = items[range].map {
                EnrichmentInput(term: $0.term, contextSentence: $0.contextSentence, dictionaryMeaning: $0.meaning)
            }
            var sentences: [String] = []
            for input in inputs {
                let sentence = String(input.contextSentence.prefix(Self.maxSentenceLength))
                if !sentences.contains(sentence) { sentences.append(sentence) }
            }
            do {
                let output = try await enricher.enrich(inputs, sentences: sentences)
                usedAI = true
                for index in range {
                    Self.apply(output.words, to: &items[index])
                }
                idioms += output.idioms
            } catch {
                // このチャンクは辞書の結果のまま進める
                continue
            }
        }

        let existingTerms = Set(items.map { $0.term.lowercased() })
        items += Self.validatedIdioms(idioms, body: body, sentences: tokenized.sentences, existingTerms: existingTerms)
        items.sort { $0.firstLocation < $1.firstLocation }
        return ExtractionResult(items: items, usedAI: usedAI)
    }

    static func apply(_ entries: [EnrichedEntry], to item: inout ExtractedItem) {
        guard let entry = entries.first(where: { $0.term.lowercased() == item.term.lowercased() }) else { return }
        let meaning = entry.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
        if !meaning.isEmpty { item.meaning = meaning }
        item.distractors = cleanedDistractors(entry.distractors, excluding: item.meaning)
    }

    static func cleanedDistractors(_ raw: [String], excluding meaning: String) -> [String] {
        var result: [String] = []
        for distractor in raw {
            let trimmed = distractor.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty && trimmed != meaning && !result.contains(trimmed) {
                result.append(trimmed)
            }
        }
        return Array(result.prefix(maxDistractors))
    }

    /// 本文中に実在する2語以上の熟語だけを採用する
    static func validatedIdioms(
        _ idioms: [EnrichedEntry], body: String, sentences: [String], existingTerms: Set<String>
    ) -> [ExtractedItem] {
        var seen = existingTerms
        var result: [ExtractedItem] = []
        for idiom in idioms {
            let term = idiom.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = idiom.meaning.trimmingCharacters(in: .whitespacesAndNewlines)
            let key = term.lowercased()
            guard term.contains(" "), !meaning.isEmpty, !seen.contains(key) else { continue }
            let spans = TextSearch.occurrences(of: term, in: body)
            guard !spans.isEmpty else { continue }
            seen.insert(key)
            let sentence = sentences.first { !TextSearch.occurrences(of: term, in: $0).isEmpty } ?? ""
            result.append(ExtractedItem(
                term: key,
                meaning: meaning,
                distractors: cleanedDistractors(idiom.distractors, excluding: meaning),
                contextSentence: sentence,
                occurrences: spans,
                source: .ai
            ))
        }
        return result
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/TextSearchTests -only-testing:TangomiruTests/ExtractionPipelineTests`）
Expected: `** TEST SUCCEEDED **`。NLTagger が `hamlet` 等を固有名詞と判定して `words` の一部が落ちる場合は、その語を別の一般名詞（例: `thimble`）に差し替える（テスト対象はパイプラインであり NLTagger ではないため）。

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Extraction TangomiruTests
git commit -m "Add extraction pipeline with AI enrichment fallback"
```

---

### Task 9: Foundation Models による上乗せ実装

**Files:**
- Create: `Tangomiru/Extraction/FoundationModelsEnricher.swift`
- Test: `TangomiruTests/FoundationModelsEnricherTests.swift`

**Interfaces:**
- Consumes: `VocabEnricher`, `EnrichmentInput`, `EnrichedEntry`, `EnrichmentOutput`
- Produces: `nonisolated struct FoundationModelsEnricher: VocabEnricher { init(); static func prompt(inputs: [EnrichmentInput], sentences: [String]) -> String }`

- [ ] **Step 1: 失敗するテストを書く**

`TangomiruTests/FoundationModelsEnricherTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct FoundationModelsEnricherTests {
    @Test func promptListsSentencesAndTerms() {
        let prompt = FoundationModelsEnricher.prompt(
            inputs: [EnrichmentInput(term: "abyss", contextSentence: "Into the abyss.", dictionaryMeaning: "深淵")],
            sentences: ["Into the abyss."]
        )
        #expect(prompt == """
        # 例文
        - Into the abyss.
        # 語（見出し語: 辞書の訳）
        - abyss: 深淵
        """)
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsEnricher().isAvailable
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/FoundationModelsEnricherTests`）
Expected: `cannot find 'FoundationModelsEnricher' in scope`

- [ ] **Step 3: 実装を書く**

`Tangomiru/Extraction/FoundationModelsEnricher.swift`:

```swift
import Foundation
import FoundationModels

@Generable
nonisolated struct GeneratedEntry: Sendable {
    @Guide(description: "英語の見出し語。入力された語はそのままの綴り、熟語は例文に出てくる形そのまま")
    var term: String
    @Guide(description: "例文の文脈に合った簡潔な日本語訳（20文字以内）")
    var meaning: String
    @Guide(description: "正解と紛らわしいが意味が異なる日本語の誤答", .count(3))
    var distractors: [String]
}

@Generable
nonisolated struct GeneratedEnrichment: Sendable {
    @Guide(description: "入力された各語の文脈訳と誤答。入力と同じ順番")
    var words: [GeneratedEntry]
    @Guide(description: "例文に含まれるが入力に無い、2語以上の英語の熟語・句動詞", .maximumCount(5))
    var idioms: [GeneratedEntry]
}

nonisolated struct FoundationModelsEnricher: VocabEnricher {
    static let instructions = """
    あなたは日本人の英語学習者のための英和辞書編集者です。
    与えられた英語の語が例文の中でどの意味で使われているかを判断し、簡潔な日本語訳を付けてください。
    4択クイズ用に、正解と紛らわしいが意味の異なる日本語の誤答を3つ作ってください。
    例文に含まれる熟語・句動詞で入力に無いものがあれば、例文に出てくる形のまま追加してください。
    """

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func enrich(_ inputs: [EnrichmentInput], sentences: [String]) async throws -> EnrichmentOutput {
        // チャンクごとに新しいセッションを使い、コンテキストを溜めない
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: Self.prompt(inputs: inputs, sentences: sentences),
            generating: GeneratedEnrichment.self
        )
        let content = response.content
        return EnrichmentOutput(words: content.words.map(Self.entry), idioms: content.idioms.map(Self.entry))
    }

    static func prompt(inputs: [EnrichmentInput], sentences: [String]) -> String {
        var lines = ["# 例文"]
        lines += sentences.map { "- \($0)" }
        lines.append("# 語（見出し語: 辞書の訳）")
        lines += inputs.map { "- \($0.term): \($0.dictionaryMeaning)" }
        return lines.joined(separator: "\n")
    }

    private static func entry(_ generated: GeneratedEntry) -> EnrichedEntry {
        EnrichedEntry(term: generated.term, meaning: generated.meaning, distractors: generated.distractors)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/FoundationModelsEnricherTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Extraction/FoundationModelsEnricher.swift TangomiruTests/FoundationModelsEnricherTests.swift
git commit -m "Add Foundation Models enricher"
```

---

### Task 10: SwiftData モデル・習得率・入力検証

**Files:**
- Create: `Tangomiru/Models/Passage.swift`, `Tangomiru/Models/VocabItem.swift`, `Tangomiru/Domain/MasteryStats.swift`, `Tangomiru/Domain/PassageInput.swift`
- Test: `TangomiruTests/MasteryStatsTests.swift`, `TangomiruTests/PassageInputTests.swift`, `TangomiruTests/PassageModelTests.swift`

**Interfaces:**
- Consumes: `ExtractedItem`, `ItemSource`, `TextSpan`, `MasteryState`, `QuizCard`, `ScoreChange`
- Produces:
  - `nonisolated struct MasteryStats: Equatable, Sendable { init(scores: [Int?]); let total: Int; func count(_: MasteryState) -> Int; var masteredRate: Double; var percentText: String }`
  - `nonisolated enum PassageInput { static let maxLength = 10_000; static let autoTitleLength = 30; enum Problem: Equatable { case empty, tooLong }; static func validate(_ body: String) -> Problem?; static func title(_ title: String, body: String) -> String }`
  - `@Model final class Passage { var title: String; var body: String; var createdAt: Date; var lastStudiedAt: Date?; var usedAI: Bool; var items: [VocabItem]; init(title: String, body: String, usedAI: Bool, createdAt: Date = .now) }`
    - extension: `var enabledItems: [VocabItem]`, `var sortedItems: [VocabItem]`, `var stats: MasteryStats`, `var quizCards: [QuizCard]`, `func applyQuizResult(_ changes: [ScoreChange], at date: Date = .now)`
  - `@Model final class VocabItem { var uuid: UUID; var term: String; var meaning: String; var distractors: [String]; var contextSentence: String; var occurrences: [TextSpan]; var isEnabled: Bool; var score: Int?; var source: ItemSource; var passage: Passage?; init(extracted: ExtractedItem, isEnabled: Bool = true) }`
    - extension: `var state: MasteryState`, `var firstLocation: Int`, `func quizCard(body: String) -> QuizCard`

- [ ] **Step 1: 失敗するテストを書く**

`TangomiruTests/MasteryStatsTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct MasteryStatsTests {
    @Test func countsEachState() {
        let stats = MasteryStats(scores: [nil, -1, 0, 1, 2, 2])
        #expect(stats.total == 6)
        #expect(stats.count(.mastered) == 2)
        #expect(stats.count(.veryWeak) == 1)
        #expect(stats.count(.unseen) == 1)
        #expect(abs(stats.masteredRate - 2.0 / 6.0) < 0.0001)
        #expect(stats.percentText == "33%")
    }

    @Test func emptyIsZero() {
        let stats = MasteryStats(scores: [])
        #expect(stats.masteredRate == 0)
        #expect(stats.percentText == "0%")
    }
}
```

`TangomiruTests/PassageInputTests.swift`:

```swift
import Testing
@testable import Tangomiru

struct PassageInputTests {
    @Test func validatesBody() {
        #expect(PassageInput.validate("  \n ") == .empty)
        #expect(PassageInput.validate(String(repeating: "a", count: 10_001)) == .tooLong)
        #expect(PassageInput.validate(String(repeating: "a", count: 10_000)) == nil)
    }

    @Test func usesGivenTitle() {
        #expect(PassageInput.title("  My title ", body: "Body") == "My title")
    }

    @Test func generatesTitleFromFirstLine() {
        #expect(PassageInput.title("", body: "\n  Short line.\nNext") == "Short line.")
        let long = String(repeating: "abcde ", count: 10)
        #expect(PassageInput.title(" ", body: long) == String(long.prefix(30)) + "…")
    }
}
```

`TangomiruTests/PassageModelTests.swift`:

```swift
import Foundation
import SwiftData
import Testing
@testable import Tangomiru

struct PassageModelTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Passage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func extracted(_ term: String, at location: Int, length: Int) -> ExtractedItem {
        ExtractedItem(
            term: term, meaning: "\(term)の意味", distractors: ["誤"], contextSentence: "ctx",
            occurrences: [TextSpan(location: location, length: length)], source: .dictionary
        )
    }

    @Test func statsCountOnlyEnabledItems() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        let a = VocabItem(extracted: extracted("a", at: 0, length: 1))
        let b = VocabItem(extracted: extracted("b", at: 2, length: 1), isEnabled: false)
        a.score = 2
        b.score = 2
        passage.items = [a, b]
        #expect(passage.stats.total == 1)
        #expect(passage.stats.masteredRate == 1)
    }

    @Test func applyQuizResultUpdatesScoresAndDate() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        let item = VocabItem(extracted: extracted("a", at: 0, length: 1))
        passage.items = [item]
        let date = Date(timeIntervalSince1970: 1_000)
        passage.applyQuizResult([ScoreChange(cardID: item.uuid, term: "a", before: nil, after: 1)], at: date)
        #expect(item.score == 1)
        #expect(passage.lastStudiedAt == date)
    }

    @Test func deletingPassageDeletesItems() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        passage.items = [VocabItem(extracted: extracted("a", at: 0, length: 1))]
        try context.save()
        context.delete(passage)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<VocabItem>()) == 0)
    }

    @Test func quizCardUsesSurfaceFromBody() throws {
        let item = VocabItem(extracted: extracted("run", at: 8, length: 7))
        let card = item.quizCard(body: "She was running fast.")
        #expect(card.highlight == "running")
        #expect(card.id == item.uuid)
        #expect(card.distractors == ["誤"])
        #expect(card.score == nil)
    }

    @Test func quizCardFallsBackToTermWhenSpanIsInvalid() {
        let item = VocabItem(extracted: extracted("run", at: 100, length: 7))
        #expect(item.quizCard(body: "short").highlight == "run")
    }

    @Test func sortedItemsFollowFirstOccurrence() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        passage.items = [
            VocabItem(extracted: extracted("later", at: 10, length: 5)),
            VocabItem(extracted: extracted("first", at: 0, length: 5)),
        ]
        #expect(passage.sortedItems.map(\.term) == ["first", "later"])
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/MasteryStatsTests -only-testing:TangomiruTests/PassageInputTests -only-testing:TangomiruTests/PassageModelTests`）
Expected: `cannot find 'MasteryStats' in scope` など

- [ ] **Step 3: 実装を書く**

`Tangomiru/Domain/MasteryStats.swift`:

```swift
nonisolated struct MasteryStats: Equatable, Sendable {
    let total: Int
    private let counts: [MasteryState: Int]

    init(scores: [Int?]) {
        total = scores.count
        counts = scores.reduce(into: [:]) { $0[MasteryState(score: $1), default: 0] += 1 }
    }

    func count(_ state: MasteryState) -> Int { counts[state, default: 0] }

    /// 出題ON の語のうち「覚えた」の割合
    var masteredRate: Double { total == 0 ? 0 : Double(count(.mastered)) / Double(total) }

    var percentText: String { "\(Int((masteredRate * 100).rounded()))%" }
}
```

`Tangomiru/Domain/PassageInput.swift`:

```swift
import Foundation

nonisolated enum PassageInput {
    static let maxLength = 10_000
    static let autoTitleLength = 30

    enum Problem: Equatable {
        case empty
        case tooLong
    }

    static func validate(_ body: String) -> Problem? {
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        if body.count > maxLength { return .tooLong }
        return nil
    }

    /// タイトル未入力なら本文の最初の空でない行から作る
    static func title(_ title: String, body: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        guard firstLine.count > autoTitleLength else { return firstLine }
        return String(firstLine.prefix(autoTitleLength)) + "…"
    }
}
```

`Tangomiru/Models/Passage.swift`:

```swift
import Foundation
import SwiftData

@Model
final class Passage {
    var title: String
    var body: String
    var createdAt: Date
    var lastStudiedAt: Date?
    /// 抽出時に AI の上乗せが行われたか
    var usedAI: Bool
    @Relationship(deleteRule: .cascade, inverse: \VocabItem.passage)
    var items: [VocabItem] = []

    init(title: String, body: String, usedAI: Bool, createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.usedAI = usedAI
        self.createdAt = createdAt
    }
}

extension Passage {
    var enabledItems: [VocabItem] { items.filter(\.isEnabled) }

    var sortedItems: [VocabItem] { items.sorted { $0.firstLocation < $1.firstLocation } }

    var stats: MasteryStats { MasteryStats(scores: enabledItems.map(\.score)) }

    var quizCards: [QuizCard] { enabledItems.map { $0.quizCard(body: body) } }

    func applyQuizResult(_ changes: [ScoreChange], at date: Date = .now) {
        let itemsByID = Dictionary(items.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        for change in changes {
            itemsByID[change.cardID]?.score = change.after
        }
        lastStudiedAt = date
    }
}
```

`Tangomiru/Models/VocabItem.swift`:

```swift
import Foundation
import SwiftData

@Model
final class VocabItem {
    var uuid: UUID
    var term: String
    var meaning: String
    var distractors: [String]
    var contextSentence: String
    var occurrences: [TextSpan]
    var isEnabled: Bool
    /// nil=未学習, -1=超苦手, 0=苦手, 1=うろ覚え, 2=覚えた
    var score: Int?
    var source: ItemSource
    var passage: Passage?

    init(extracted: ExtractedItem, isEnabled: Bool = true) {
        uuid = UUID()
        term = extracted.term
        meaning = extracted.meaning
        distractors = extracted.distractors
        contextSentence = extracted.contextSentence
        occurrences = extracted.occurrences
        self.isEnabled = isEnabled
        score = nil
        source = extracted.source
    }
}

extension VocabItem {
    var state: MasteryState { MasteryState(score: score) }

    var firstLocation: Int { occurrences.first?.location ?? .max }

    func quizCard(body: String) -> QuizCard {
        let ns = body as NSString
        var highlight = term
        if let span = occurrences.first, span.location >= 0, span.length > 0, span.end <= ns.length {
            highlight = ns.substring(with: NSRange(location: span.location, length: span.length))
        }
        return QuizCard(
            id: uuid, term: term, meaning: meaning, distractors: distractors,
            contextSentence: contextSentence, highlight: highlight, score: score
        )
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/MasteryStatsTests -only-testing:TangomiruTests/PassageInputTests -only-testing:TangomiruTests/PassageModelTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Models Tangomiru/Domain TangomiruTests
git commit -m "Add SwiftData models, mastery stats, and input validation"
```

---

### Task 11: 読解モードのハイライト分割とリンク

**Files:**
- Create: `Tangomiru/Domain/Reading/ReadingSegmenter.swift`, `Tangomiru/Domain/Reading/ReadingLink.swift`
- Test: `TangomiruTests/ReadingSegmenterTests.swift`, `TangomiruTests/ReadingLinkTests.swift`

**Interfaces:**
- Consumes: `TextSpan`
- Produces:
  - `nonisolated struct ReadingHighlight: Equatable, Sendable { let span: TextSpan; let itemID: UUID }`
  - `nonisolated struct ReadingSegment: Equatable, Sendable { let text: String; let itemID: UUID? }`
  - `nonisolated enum ReadingSegmenter { static func segments(body: String, highlights: [ReadingHighlight]) -> [ReadingSegment] }`（重なりは長い方を優先、範囲外は無視）
  - `nonisolated enum ReadingLink { static func url(for id: UUID) -> URL; static func itemID(from url: URL) -> UUID? }`

- [ ] **Step 1: 失敗するテストを書く**

`TangomiruTests/ReadingSegmenterTests.swift`:

```swift
import Foundation
import Testing
@testable import Tangomiru

struct ReadingSegmenterTests {
    let a = UUID()
    let b = UUID()

    @Test func noHighlightsGivesPlainText() {
        #expect(ReadingSegmenter.segments(body: "Hello", highlights: []) == [ReadingSegment(text: "Hello", itemID: nil)])
    }

    @Test func splitsAroundHighlights() {
        let segments = ReadingSegmenter.segments(
            body: "I gave up today.",
            highlights: [ReadingHighlight(span: TextSpan(location: 2, length: 7), itemID: a)]
        )
        #expect(segments == [
            ReadingSegment(text: "I ", itemID: nil),
            ReadingSegment(text: "gave up", itemID: a),
            ReadingSegment(text: " today.", itemID: nil),
        ])
    }

    @Test func prefersLongerOverlappingHighlight() {
        let segments = ReadingSegmenter.segments(
            body: "I gave up today.",
            highlights: [
                ReadingHighlight(span: TextSpan(location: 2, length: 4), itemID: b),
                ReadingHighlight(span: TextSpan(location: 2, length: 7), itemID: a),
            ]
        )
        #expect(segments.compactMap(\.itemID) == [a])
    }

    @Test func ignoresOutOfBoundsHighlights() {
        let segments = ReadingSegmenter.segments(
            body: "short",
            highlights: [ReadingHighlight(span: TextSpan(location: 3, length: 10), itemID: a)]
        )
        #expect(segments == [ReadingSegment(text: "short", itemID: nil)])
    }

    @Test func handlesEmojiOffsets() {
        let segments = ReadingSegmenter.segments(
            body: "😀 give up",
            highlights: [ReadingHighlight(span: TextSpan(location: 3, length: 7), itemID: a)]
        )
        #expect(segments == [ReadingSegment(text: "😀 ", itemID: nil), ReadingSegment(text: "give up", itemID: a)])
    }
}
```

`TangomiruTests/ReadingLinkTests.swift`:

```swift
import Foundation
import Testing
@testable import Tangomiru

struct ReadingLinkTests {
    @Test func roundTripsItemID() {
        let id = UUID()
        #expect(ReadingLink.itemID(from: ReadingLink.url(for: id)) == id)
    }

    @Test func rejectsOtherURLs() {
        #expect(ReadingLink.itemID(from: URL(string: "https://example.com/item/x")!) == nil)
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/ReadingSegmenterTests -only-testing:TangomiruTests/ReadingLinkTests`）
Expected: `cannot find 'ReadingSegmenter' in scope`

- [ ] **Step 3: 実装を書く**

`Tangomiru/Domain/Reading/ReadingSegmenter.swift`:

```swift
import Foundation

nonisolated struct ReadingHighlight: Equatable, Sendable {
    let span: TextSpan
    let itemID: UUID
}

nonisolated struct ReadingSegment: Equatable, Sendable {
    let text: String
    /// nil は通常のテキスト
    let itemID: UUID?
}

nonisolated enum ReadingSegmenter {
    /// 本文をハイライト区間と通常区間に分ける。重なる区間は長い方（熟語）を優先する
    static func segments(body: String, highlights: [ReadingHighlight]) -> [ReadingSegment] {
        let ns = body as NSString
        let candidates = highlights
            .filter { $0.span.location >= 0 && $0.span.length > 0 && $0.span.end <= ns.length }
            .sorted { $0.span.length != $1.span.length ? $0.span.length > $1.span.length : $0.span.location < $1.span.location }
        var accepted: [ReadingHighlight] = []
        for highlight in candidates where !accepted.contains(where: { $0.span.overlaps(highlight.span) }) {
            accepted.append(highlight)
        }
        accepted.sort { $0.span.location < $1.span.location }

        var segments: [ReadingSegment] = []
        var cursor = 0
        for highlight in accepted {
            if highlight.span.location > cursor {
                let plain = NSRange(location: cursor, length: highlight.span.location - cursor)
                segments.append(ReadingSegment(text: ns.substring(with: plain), itemID: nil))
            }
            let range = NSRange(location: highlight.span.location, length: highlight.span.length)
            segments.append(ReadingSegment(text: ns.substring(with: range), itemID: highlight.itemID))
            cursor = highlight.span.end
        }
        if cursor < ns.length {
            segments.append(ReadingSegment(text: ns.substring(from: cursor), itemID: nil))
        }
        return segments
    }
}
```

`Tangomiru/Domain/Reading/ReadingLink.swift`:

```swift
import Foundation

/// 読解モードの本文中リンク（tangomiru://item/<UUID>）
nonisolated enum ReadingLink {
    static let scheme = "tangomiru"
    static let host = "item"

    static func url(for id: UUID) -> URL {
        URL(string: "\(scheme)://\(host)/\(id.uuidString)")!
    }

    static func itemID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
```

- [ ] **Step 4: テストが通ることを確認**

Run: `TEST`（`-only-testing:TangomiruTests/ReadingSegmenterTests -only-testing:TangomiruTests/ReadingLinkTests`）
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: コミット**

```bash
git add Tangomiru/Domain/Reading TangomiruTests
git commit -m "Add reading-mode segmenter and item links"
```

---

### Task 12: アプリ基盤・一覧・入力・抽出結果確認

**Files:**
- Create: `Tangomiru/App/AppServices.swift`, `Tangomiru/Features/Shared/MasteryState+UI.swift`, `Tangomiru/Features/Shared/VocabLabel.swift`, `Tangomiru/Features/Library/LibraryView.swift`, `Tangomiru/Features/Input/PassageInputView.swift`, `Tangomiru/Features/Input/ExtractionReviewView.swift`
- Modify: `Tangomiru/TangomiruApp.swift`（全体を置き換え）
- Delete: `Tangomiru/ContentView.swift`

**Interfaces:**
- Consumes: `EJDictionary.loadBundled`, `BasicWords.loadBundled`, `DictionaryExtractor`, `FoundationModelsEnricher`, `ExtractionPipeline.run`, `ExtractionResult`, `PassageInput`, `Passage`, `VocabItem(extracted:isEnabled:)`, `MasteryState`
- Produces:
  - `@Observable final class AppServices { enum Status { case loading, ready, failed(String); var isReady: Bool }; private(set) var status: Status; func load() async; func makePipeline() -> ExtractionPipeline?; func fallbackMeanings(count: Int = 30) -> [String] }`
  - `extension MasteryState { var color: Color; var highlightBackground: Color }`
  - `struct VocabLabel: View { init(term: String, meaning: String, state: MasteryState?) }`、`struct MasteryBadge: View { init(state: MasteryState) }`
  - `struct LibraryView: View`、`struct PassageRow: View { let passage: Passage }`
  - `struct PassageInputView: View`、`struct ExtractionReviewView: View { init(title: String, passageBody: String, result: ExtractionResult, onSaved: @escaping () -> Void) }`

- [ ] **Step 1: アプリ基盤を書く**

`Tangomiru/App/AppServices.swift`:

```swift
import Foundation
import Observation

/// 辞書などアプリ全体で共有するリソース
@Observable
final class AppServices {
    enum Status {
        case loading
        case ready
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    private(set) var status: Status = .loading
    private var dictionary: EJDictionary?
    private var basicWords: Set<String> = []

    func load() async {
        guard dictionary == nil else { return }
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                (try EJDictionary.loadBundled(), try BasicWords.loadBundled())
            }.value
            dictionary = loaded.0
            basicWords = loaded.1
            status = .ready
        } catch {
            status = .failed("辞書データを読み込めませんでした。アプリを再インストールしてください。")
        }
    }

    func makePipeline() -> ExtractionPipeline? {
        guard let dictionary else { return nil }
        return ExtractionPipeline(
            extractor: DictionaryExtractor(dictionary: dictionary, basicWords: basicWords),
            enricher: FoundationModelsEnricher()
        )
    }

    /// 誤答が足りないときの補充用に、辞書からランダムな訳を返す
    func fallbackMeanings(count: Int = 30) -> [String] {
        guard let dictionary else { return [] }
        var rng = SeededRandom()
        return dictionary.randomMeanings(count: count, using: &rng)
    }
}
```

`Tangomiru/TangomiruApp.swift`（全体を置き換え）:

```swift
//
//  TangomiruApp.swift
//  Tangomiru
//
//  Created by harumi.sagawa on 2026/09/30.
//

import SwiftData
import SwiftUI

@main
struct TangomiruApp: App {
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(services)
                .task { await services.load() }
        }
        .modelContainer(for: Passage.self)
    }
}
```

```bash
git rm Tangomiru/ContentView.swift
```

- [ ] **Step 2: 共通 UI を書く**

`Tangomiru/Features/Shared/MasteryState+UI.swift`:

```swift
import SwiftUI

extension MasteryState {
    var color: Color {
        switch self {
        case .veryWeak: .red
        case .weak: .pink
        case .unseen: .gray
        case .vague: .orange
        case .mastered: .green
        }
    }

    /// 読解モードのハイライト背景（超苦手=濃い赤、苦手=赤系、うろ覚え=黄系、未学習=グレー系）
    var highlightBackground: Color {
        switch self {
        case .veryWeak: .red.opacity(0.4)
        case .weak: .red.opacity(0.18)
        case .unseen: .gray.opacity(0.2)
        case .vague: .yellow.opacity(0.35)
        case .mastered: .clear
        }
    }
}
```

`Tangomiru/Features/Shared/VocabLabel.swift`:

```swift
import SwiftUI

struct VocabLabel: View {
    let term: String
    let meaning: String
    let state: MasteryState?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(term).font(.headline)
                if let state { MasteryBadge(state: state) }
            }
            Text(meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
    }
}

struct MasteryBadge: View {
    let state: MasteryState

    var body: some View {
        Text(state.label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(state.color)
            .background(state.color.opacity(0.15), in: .capsule)
    }
}
```

- [ ] **Step 3: 一覧・入力・抽出結果確認画面を書く**

`Tangomiru/Features/Library/LibraryView.swift`:

```swift
import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Passage.createdAt, order: .reverse) private var passages: [Passage]
    @State private var isAddingPassage = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(passages) { passage in
                    NavigationLink(value: passage) {
                        PassageRow(passage: passage)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(passages[index]) }
                }
            }
            .overlay {
                if passages.isEmpty {
                    ContentUnavailableView(
                        "英文がありません", systemImage: "text.book.closed",
                        description: Text("右上の＋から英文を貼り付けて始めましょう")
                    )
                }
            }
            .navigationTitle("Tangomiru")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("英文を追加", systemImage: "plus") { isAddingPassage = true }
                }
            }
            .sheet(isPresented: $isAddingPassage) {
                PassageInputView()
            }
        }
    }
}

struct PassageRow: View {
    let passage: Passage

    var body: some View {
        let stats = passage.stats
        VStack(alignment: .leading, spacing: 6) {
            Text(passage.title).font(.headline).lineLimit(1)
            ProgressView(value: stats.masteredRate)
            HStack {
                Text("習得率 \(stats.percentText)")
                Spacer()
                if let date = passage.lastStudiedAt {
                    Text("最終学習 \(date.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    Text("未学習")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
```

`Tangomiru/Features/Input/PassageInputView.swift`:

```swift
import SwiftUI

struct PassageInputView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    @State private var title = ""
    @State private var bodyText = ""
    @State private var isExtracting = false
    @State private var result: ExtractionResult?

    private var problem: PassageInput.Problem? { PassageInput.validate(bodyText) }

    var body: some View {
        NavigationStack {
            Form {
                Section("タイトル（省略可）") {
                    TextField("例: ニュース記事", text: $title)
                }
                Section {
                    TextEditor(text: $bodyText)
                        .frame(minHeight: 240)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                } header: {
                    Text("英文")
                } footer: {
                    footer
                }
            }
            .disabled(isExtracting)
            .overlay {
                if isExtracting {
                    ProgressView("抽出中…")
                        .padding()
                        .background(.regularMaterial, in: .rect(cornerRadius: 12))
                }
            }
            .navigationTitle("英文を追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("抽出") { Task { await extract() } }
                        .disabled(problem != nil || isExtracting || !services.status.isReady)
                }
            }
            .navigationDestination(item: $result) { result in
                ExtractionReviewView(
                    title: PassageInput.title(title, body: bodyText),
                    passageBody: bodyText,
                    result: result
                ) {
                    dismiss()
                }
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        switch problem {
        case .empty:
            Text("英文を貼り付けてください")
        case .tooLong:
            Text("長すぎます（\(bodyText.count) / \(PassageInput.maxLength)文字）").foregroundStyle(.red)
        case nil:
            Text("\(bodyText.count) / \(PassageInput.maxLength)文字")
        }
        if case .failed(let message) = services.status {
            Text(message).foregroundStyle(.red)
        }
    }

    private func extract() async {
        guard let pipeline = services.makePipeline() else { return }
        isExtracting = true
        result = await pipeline.run(bodyText)
        isExtracting = false
    }
}
```

`Tangomiru/Features/Input/ExtractionReviewView.swift`:

```swift
import SwiftData
import SwiftUI

struct ExtractionReviewView: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let passageBody: String
    let result: ExtractionResult
    let onSaved: () -> Void
    @State private var enabled: [Bool]

    init(title: String, passageBody: String, result: ExtractionResult, onSaved: @escaping () -> Void) {
        self.title = title
        self.passageBody = passageBody
        self.result = result
        self.onSaved = onSaved
        _enabled = State(initialValue: Array(repeating: true, count: result.items.count))
    }

    var body: some View {
        List {
            if !result.items.isEmpty {
                if !result.usedAI {
                    Section {
                        Label("辞書モードで抽出しました", systemImage: "book")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("\(result.items.count)語を抽出（出題ON \(enabled.filter { $0 }.count)語）") {
                    ForEach(result.items.indices, id: \.self) { index in
                        Toggle(isOn: $enabled[index]) {
                            VocabLabel(term: result.items[index].term, meaning: result.items[index].meaning, state: nil)
                        }
                    }
                }
            }
        }
        .overlay {
            if result.items.isEmpty {
                ContentUnavailableView(
                    "出題できる語が見つかりませんでした", systemImage: "text.magnifyingglass",
                    description: Text("英語以外の文章や、基本語だけの文章からは語を抽出できません")
                )
            }
        }
        .navigationTitle("抽出結果")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save).disabled(result.items.isEmpty)
            }
        }
    }

    private func save() {
        let passage = Passage(title: title, body: passageBody, usedAI: result.usedAI)
        modelContext.insert(passage)
        passage.items = zip(result.items, enabled).map { VocabItem(extracted: $0, isEnabled: $1) }
        onSaved()
    }
}
```

- [ ] **Step 4: ビルドと全テストを確認**

Run: `BUILD`
Expected: `** BUILD SUCCEEDED **`

Run: `TEST`
Expected: `** TEST SUCCEEDED **`

- [ ] **Step 5: シミュレータで動作確認**

```bash
xcrun simctl boot "iPhone 17" 2>/dev/null; open -a Simulator
xcrun simctl install "iPhone 17" build/DerivedData/Build/Products/Debug-iphonesimulator/Tangomiru.app
xcrun simctl launch "iPhone 17" harumidiv.Tangomiru
```

確認すること:
- 空の一覧に「英文がありません」が出る
- ＋ → `The ubiquitous smartphone has transformed how we communicate. People took it for granted.` を貼り付け → 抽出 → `ubiquitous` などが意味付きで並ぶ（シミュレータでは Apple Intelligence が使えない場合が多く、その場合「辞書モードで抽出しました」が出る）
- トグルを切り替えて保存 → 一覧に行が出る、スワイプで削除できる

- [ ] **Step 6: コミット**

```bash
git add Tangomiru
git commit -m "Add library, passage input, and extraction review screens"
```

---

### Task 13: 英文詳細と単語一覧

**Files:**
- Create: `Tangomiru/Features/Detail/PassageDetailView.swift`, `Tangomiru/Features/Detail/ItemListView.swift`
- Modify: `Tangomiru/Features/Library/LibraryView.swift`（`.navigationTitle("Tangomiru")` の直後に destination を追加）

**Interfaces:**
- Consumes: `Passage.stats`, `Passage.sortedItems`, `MasteryStats`, `MasteryState.displayOrder`, `QuizLength`, `VocabLabel`, `MasteryBadge`
- Produces: `struct PassageDetailView: View { let passage: Passage }`、`struct ItemListView: View { let passage: Passage }`

- [ ] **Step 1: 詳細画面と単語一覧を書く**

`Tangomiru/Features/Detail/ItemListView.swift`:

```swift
import SwiftData
import SwiftUI

struct ItemListView: View {
    let passage: Passage

    var body: some View {
        List(passage.sortedItems) { item in
            ItemToggleRow(item: item)
        }
        .navigationTitle("単語一覧")
    }
}

private struct ItemToggleRow: View {
    @Bindable var item: VocabItem

    var body: some View {
        Toggle(isOn: $item.isEnabled) {
            VocabLabel(term: item.term, meaning: item.meaning, state: item.state)
        }
    }
}
```

`Tangomiru/Features/Detail/PassageDetailView.swift`:

```swift
import SwiftUI

struct PassageDetailView: View {
    let passage: Passage
    @AppStorage("quizLength") private var quizLengthRaw = QuizLength.ten.rawValue

    private var quizLength: Binding<QuizLength> {
        Binding(
            get: { QuizLength(rawValue: quizLengthRaw) ?? .ten },
            set: { quizLengthRaw = $0.rawValue }
        )
    }

    var body: some View {
        let stats = passage.stats
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("習得率 \(stats.percentText)").font(.title2.bold())
                    ProgressView(value: stats.masteredRate)
                    HStack {
                        ForEach(MasteryState.displayOrder) { state in
                            VStack(spacing: 2) {
                                Text("\(stats.count(state))").font(.headline)
                                Text(state.label).font(.caption2)
                            }
                            .foregroundStyle(state.color)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section("クイズ") {
                Picker("出題数", selection: quizLength) {
                    ForEach(QuizLength.allCases) { length in
                        Text(length.label).tag(length)
                    }
                }
                .pickerStyle(.segmented)
            }
            Section {
                NavigationLink {
                    ItemListView(passage: passage)
                } label: {
                    Label("単語一覧（\(passage.items.count)語）", systemImage: "list.bullet")
                }
            }
        }
        .navigationTitle(passage.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}
```

`Tangomiru/Features/Library/LibraryView.swift` の `.navigationTitle("Tangomiru")` の直後に追加:

```swift
            .navigationDestination(for: Passage.self) { passage in
                PassageDetailView(passage: passage)
            }
```

- [ ] **Step 2: ビルド確認**

Run: `BUILD`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: シミュレータで確認**

Task 12 Step 5 のコマンドで再インストール・起動し、次を確認:
- 一覧の行をタップ → 詳細に習得率 0% と内訳（未学習 = 出題ON 語数）が出る
- 出題数セグメントを 20問 にしてから戻って再度開くと 20問 のまま
- 単語一覧でトグルを OFF → 戻ると内訳の未学習数が減る

- [ ] **Step 4: コミット**

```bash
git add Tangomiru/Features
git commit -m "Add passage detail and item list screens"
```

---

### Task 14: クイズ画面と結果画面

**Files:**
- Create: `Tangomiru/Features/Quiz/ContextHighlighter.swift`, `Tangomiru/Features/Quiz/QuizView.swift`, `Tangomiru/Features/Quiz/QuizResultView.swift`
- Modify: `Tangomiru/Features/Detail/PassageDetailView.swift`（クイズ開始ボタンと fullScreenCover を追加）
- Test: `TangomiruTests/ContextHighlighterTests.swift`

**Interfaces:**
- Consumes: `QuizSession`, `QuizQuestion`, `AnswerFeedback`, `ScoreChange`, `Passage.quizCards`, `Passage.applyQuizResult`, `AppServices.fallbackMeanings`, `TextSearch.occurrences`
- Produces:
  - `enum ContextHighlighter { static func attributed(sentence: String, highlight: String) -> AttributedString }`
  - `struct QuizView: View { init(passage: Passage, length: QuizLength) }`
  - `struct QuizResultView: View { init(session: QuizSession, onClose: @escaping () -> Void) }`

- [ ] **Step 1: 失敗するテストを書く**

`TangomiruTests/ContextHighlighterTests.swift`:

```swift
import Foundation
import Testing
@testable import Tangomiru

struct ContextHighlighterTests {
    @Test func emphasizesFirstMatch() {
        let attributed = ContextHighlighter.attributed(sentence: "She was running fast.", highlight: "running")
        #expect(String(attributed.characters) == "She was running fast.")
        let emphasized = attributed.runs
            .filter { $0.inlinePresentationIntent == .stronglyEmphasized }
            .map { String(attributed[$0.range].characters) }
        #expect(emphasized == ["running"])
    }

    @Test func leavesSentenceUnchangedWhenNotFound() {
        let attributed = ContextHighlighter.attributed(sentence: "Nothing here.", highlight: "run")
        #expect(attributed.runs.allSatisfy { $0.inlinePresentationIntent == nil })
    }
}
```

- [ ] **Step 2: テストが失敗することを確認**

Run: `TEST`（`-only-testing:TangomiruTests/ContextHighlighterTests`）
Expected: `cannot find 'ContextHighlighter' in scope`

- [ ] **Step 3: 実装を書く**

`Tangomiru/Features/Quiz/ContextHighlighter.swift`:

```swift
import Foundation

enum ContextHighlighter {
    /// 例文中で最初に一致した語を太字にする
    static func attributed(sentence: String, highlight: String) -> AttributedString {
        guard let span = TextSearch.occurrences(of: highlight, in: sentence).first else {
            return AttributedString(sentence)
        }
        let ns = sentence as NSString
        var match = AttributedString(ns.substring(with: NSRange(location: span.location, length: span.length)))
        match.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(ns.substring(to: span.location))
            + match
            + AttributedString(ns.substring(from: span.end))
    }
}
```

`Tangomiru/Features/Quiz/QuizResultView.swift`:

```swift
import SwiftUI

struct QuizResultView: View {
    let session: QuizSession
    let onClose: () -> Void

    var body: some View {
        let promoted = session.changes.filter(\.isPromotion)
        let demoted = session.changes.filter(\.isDemotion)
        List {
            Section {
                Text("\(session.correctCount) / \(session.questionCount) 問正解")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            if !promoted.isEmpty {
                Section("上がった語") {
                    ForEach(promoted, id: \.cardID) { ChangeRow(change: $0) }
                }
            }
            if !demoted.isEmpty {
                Section("下がった語") {
                    ForEach(demoted, id: \.cardID) { ChangeRow(change: $0) }
                }
            }
        }
        .navigationTitle("結果")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了", action: onClose)
            }
        }
    }
}

private struct ChangeRow: View {
    let change: ScoreChange

    var body: some View {
        HStack {
            Text(change.term).font(.headline)
            Spacer()
            MasteryBadge(state: MasteryState(score: change.before))
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
            MasteryBadge(state: MasteryState(score: change.after))
        }
    }
}
```

`Tangomiru/Features/Quiz/QuizView.swift`:

```swift
import SwiftUI

struct QuizView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let passage: Passage
    let length: QuizLength
    @State private var session: QuizSession?
    @State private var feedback: AnswerFeedback?
    @State private var selectedChoice: String?
    @State private var isCommitted = false

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    if let question = session.current {
                        questionView(question, session: session)
                    } else {
                        QuizResultView(session: session) { dismiss() }
                    }
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                if session?.isFinished != true {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            commit()
                            dismiss()
                        }
                    }
                }
            }
        }
        .task {
            guard session == nil else { return }
            session = QuizSession(
                cards: passage.quizCards, length: length, fallbackMeanings: services.fallbackMeanings()
            )
            if session?.isFinished == true { commit() }
        }
    }

    private func questionView(_ question: QuizQuestion, session: QuizSession) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("\(session.position + 1) / \(session.totalCount)")
                    if question.isRetry {
                        Text("もう一度").bold().foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(question.card.term)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(ContextHighlighter.attributed(sentence: question.card.contextSentence, highlight: question.card.highlight))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    ForEach(question.choices, id: \.self) { choice in
                        Button {
                            answer(choice)
                        } label: {
                            Text(choice)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(background(for: choice, question: question), in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(feedback != nil)
                    }
                }

                if let feedback {
                    Text(feedback.isCorrect ? "正解！" : "不正解… 正解は「\(feedback.correctAnswer)」")
                        .font(.headline)
                        .foregroundStyle(feedback.isCorrect ? .green : .red)
                    Button("次へ", action: next)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private func background(for choice: String, question: QuizQuestion) -> Color {
        guard feedback != nil else { return Self.neutralBackground }
        if choice == question.card.meaning { return .green.opacity(0.25) }
        if choice == selectedChoice { return .red.opacity(0.25) }
        return Self.neutralBackground
    }

    private static let neutralBackground = Color.secondary.opacity(0.12)

    private func answer(_ choice: String) {
        guard feedback == nil else { return }
        selectedChoice = choice
        feedback = session?.answer(choice)
    }

    private func next() {
        session?.advance()
        feedback = nil
        selectedChoice = nil
        if session?.isFinished == true { commit() }
    }

    /// 解答済みの分のスコアを保存する（途中で閉じた場合も反映）
    private func commit() {
        guard !isCommitted, let session, !session.changes.isEmpty else { return }
        passage.applyQuizResult(session.changes)
        isCommitted = true
    }
}
```

`Tangomiru/Features/Detail/PassageDetailView.swift` を変更:

1. `@AppStorage` の下に追加:

```swift
    @State private var isQuizPresented = false
```

2. `Section("クイズ")` の `Picker(...) ... .pickerStyle(.segmented)` の直後に追加:

```swift
                Button("クイズを始める", systemImage: "play.fill") { isQuizPresented = true }
                    .disabled(stats.total == 0)
                if stats.total == 0 {
                    Text("出題ONの語がありません").font(.footnote).foregroundStyle(.secondary)
                }
```

3. `.navigationBarTitleDisplayMode(.inline)` の直後に追加:

```swift
        .fullScreenCover(isPresented: $isQuizPresented) {
            QuizView(passage: passage, length: quizLength.wrappedValue)
        }
```

- [ ] **Step 4: テストとビルドを確認**

Run: `TEST`
Expected: `** TEST SUCCEEDED **`（ContextHighlighterTests を含む全テスト）

- [ ] **Step 5: シミュレータで確認**

Task 12 Step 5 のコマンドで再インストール・起動し、次を確認:
- 詳細 → クイズを始める → 見出し語・例文（該当語が太字）・4択が出る
- わざと間違える → 赤/緑の表示と「正解は…」、「次へ」→ 3問後に「もう一度」付きで同じ語が出る
- 最後まで解く → 結果画面に正答数と上がった/下がった語 → 完了 → 詳細の内訳が変わっている
- 途中で「閉じる」→ 解いた分だけ内訳に反映されている
- 単語一覧で全部 OFF → 「クイズを始める」が押せない

- [ ] **Step 6: コミット**

```bash
git add Tangomiru/Features TangomiruTests/ContextHighlighterTests.swift
git commit -m "Add quiz and result screens"
```

---

### Task 15: 読解モード

**Files:**
- Create: `Tangomiru/Features/Reading/ReadingView.swift`
- Modify: `Tangomiru/Features/Detail/PassageDetailView.swift`（読解モードへのリンクを追加）

**Interfaces:**
- Consumes: `ReadingSegmenter.segments`, `ReadingHighlight`, `ReadingLink`, `Passage.enabledItems`, `VocabItem.state`, `MasteryState.highlightBackground`, `MasteryBadge`
- Produces: `struct ReadingView: View { let passage: Passage }`

- [ ] **Step 1: 読解モードを書く**

`Tangomiru/Features/Reading/ReadingView.swift`:

```swift
import SwiftUI

struct ReadingView: View {
    let passage: Passage
    @State private var selectedItem: VocabItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                legend
                Text(attributedBody)
                    .font(.body)
                    .lineSpacing(6)
                    .tint(.primary)
                    .textSelection(.disabled)
                    .environment(\.openURL, OpenURLAction { url in
                        if let id = ReadingLink.itemID(from: url) {
                            selectedItem = passage.items.first { $0.uuid == id }
                        }
                        return .handled
                    })
            }
            .padding()
        }
        .navigationTitle("読解モード")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(item: item)
                .presentationDetents([.height(240)])
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach([MasteryState.veryWeak, .weak, .vague, .unseen]) { state in
                MasteryBadge(state: state)
            }
            Spacer()
            Text("\(passage.stats.percentText) 習得").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var attributedBody: AttributedString {
        let itemsByID = Dictionary(passage.items.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let highlights = passage.enabledItems
            .filter { $0.state != .mastered }
            .flatMap { item in item.occurrences.map { ReadingHighlight(span: $0, itemID: item.uuid) } }
        var result = AttributedString()
        for segment in ReadingSegmenter.segments(body: passage.body, highlights: highlights) {
            var part = AttributedString(segment.text)
            if let id = segment.itemID, let item = itemsByID[id] {
                part.backgroundColor = item.state.highlightBackground
                part.link = ReadingLink.url(for: id)
                if item.state == .veryWeak {
                    part.inlinePresentationIntent = .stronglyEmphasized
                }
            }
            result += part
        }
        return result
    }
}

private struct ItemDetailSheet: View {
    let item: VocabItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.term).font(.title2.bold())
                MasteryBadge(state: item.state)
            }
            Text(item.meaning).font(.body)
            Text(item.contextSentence).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
```

`Tangomiru/Features/Detail/PassageDetailView.swift` の最後の `Section { NavigationLink { ItemListView ... } }` の中、`ItemListView` のリンクの前に追加:

```swift
                NavigationLink {
                    ReadingView(passage: passage)
                } label: {
                    Label("読解モード", systemImage: "text.viewfinder")
                }
```

- [ ] **Step 2: ビルド確認**

Run: `BUILD`
Expected: `** BUILD SUCCEEDED **`

- [ ] **Step 3: シミュレータで確認**

Task 12 Step 5 のコマンドで再インストール・起動し、次を確認:
- 詳細 → 読解モード → 本文が表示され、未学習の語がグレー背景になっている
- ハイライトされた語をタップ → 下から小さなシートで意味・状態・例文が出る
- クイズで語を「覚えた」にする → 読解モードでその語のハイライトが消える
- `😀 “Smart quotes” and ubiquitous devices.` のような本文で、ハイライト位置がずれない

- [ ] **Step 4: コミット**

```bash
git add Tangomiru/Features
git commit -m "Add reading mode with tappable highlights"
```

---

### Task 16: 全体検証

**Files:** なし（検証のみ）

- [ ] **Step 1: 全テスト**

Run: `TEST`
Expected: `** TEST SUCCEEDED **`、`failed` が 0 件。

- [ ] **Step 2: エンドツーエンドの手動確認（シミュレータ）**

Task 12 Step 5 のコマンドで起動し、次の英文で「入力 → 抽出 → 保存 → クイズ（全問）→ 読解モード」を通しで行う:

```
The ubiquitous smartphone has fundamentally transformed how we communicate. Many people took it for granted until the outage, when they had to give up their devices for a day. Researchers argue that this dependence is unprecedented.
```

確認:
- 抽出に `ubiquitous` / `fundamentally` / `unprecedented` などが含まれ、`the` / `people` / `day` などの基本語が含まれない
- 抽出結果に `n't` や `'s` のような断片が無い
- クイズの選択肢は毎回4つで、正解が1つだけ
- アプリを終了・再起動しても英文とスコアが残っている

- [ ] **Step 3: 実機確認（Apple Intelligence 対応端末がある場合）**

Xcode から実機にインストールし、同じ英文で抽出 → 「辞書モードで抽出しました」が出ないこと、`give up` などの熟語が追加されていること、選択肢に紛らわしい誤答が出ることを確認する。非対応端末では辞書モードで全機能が動くことを確認する。
