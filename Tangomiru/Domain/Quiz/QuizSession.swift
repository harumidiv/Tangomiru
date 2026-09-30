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

    /// 解答済みの割合（0〜1）。いま表示中の問題は解答した時点で数える
    var progress: Double {
        guard totalCount > 0 else { return 1 }
        return Double(position + (lastFeedback == nil ? 0 : 1)) / Double(totalCount)
    }

    @discardableResult
    mutating func answer(_ choice: String) -> AnswerFeedback {
        guard let current else { return AnswerFeedback(isCorrect: false, correctAnswer: "") }
        return record(isCorrect: choice == current.card.meaning)
    }

    /// 「わからない」として不正解と同じ扱いにする（スコア −1、3問後に再出題）
    @discardableResult
    mutating func skip() -> AnswerFeedback {
        guard current != nil else { return AnswerFeedback(isCorrect: false, correctAnswer: "") }
        return record(isCorrect: false)
    }

    private mutating func record(isCorrect: Bool) -> AnswerFeedback {
        if let lastFeedback { return lastFeedback }
        let entry = queue[position]
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
