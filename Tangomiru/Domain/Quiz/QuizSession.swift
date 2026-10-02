import Foundation

nonisolated struct QuizQuestion: Equatable, Sendable {
    let card: QuizCard
    let choices: [String]
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

/// 1回分のクイズ。出題順・スコア変化・間違えた語を管理する（保存は呼び出し側が changes を反映する）。
/// 間違えても回の途中で問題は増えず、間違えた語は終了後に復習の回（isReview）で出し直す
nonisolated struct QuizSession: Sendable {
    private let queue: [QuizCard]
    private var rng: SeededRandom
    private let passageMeanings: [String]
    private let fallbackMeanings: [String]
    private var lastFeedback: AnswerFeedback?

    /// 復習の回はスコアを変えない（練習扱い）
    let isReview: Bool
    private(set) var current: QuizQuestion?
    private(set) var position = 0
    let questionCount: Int
    private(set) var correctCount = 0
    /// 解答によるスコア変化（解答順。復習の回では空）
    private(set) var changes: [ScoreChange] = []
    /// 間違えた（時間切れ・SKIP を含む）語（解答順）
    private(set) var wrongCards: [QuizCard] = []

    /// passageMeanings は誤答の候補にする英文全体の訳（出題範囲で cards を絞り込んだときに渡す。省略時は cards の訳）
    init(
        cards: [QuizCard],
        length: QuizLength,
        passageMeanings: [String]? = nil,
        fallbackMeanings: [String],
        rng: SeededRandom = SeededRandom()
    ) {
        var rng = rng
        let selected = QuizPlanner.select(from: cards, length: length, using: &rng)
        self.init(
            queue: selected, passageMeanings: passageMeanings ?? cards.map(\.meaning),
            fallbackMeanings: fallbackMeanings, isReview: false, rng: rng
        )
    }

    /// 間違えた語だけを出題する復習の回。誤答候補には英文全体の訳を使う
    init(reviewing cards: [QuizCard], passageMeanings: [String], fallbackMeanings: [String], rng: SeededRandom = SeededRandom()) {
        var rng = rng
        let shuffled = cards.shuffled(using: &rng)
        self.init(queue: shuffled, passageMeanings: passageMeanings, fallbackMeanings: fallbackMeanings, isReview: true, rng: rng)
    }

    private init(queue: [QuizCard], passageMeanings: [String], fallbackMeanings: [String], isReview: Bool, rng: SeededRandom) {
        self.queue = queue
        self.rng = rng
        self.passageMeanings = passageMeanings
        self.fallbackMeanings = fallbackMeanings
        self.isReview = isReview
        self.questionCount = queue.count
        self.current = nil
        self.current = makeQuestion(at: 0)
    }

    var totalCount: Int { queue.count }
    var isFinished: Bool { current == nil }

    @discardableResult
    mutating func answer(_ choice: String) -> AnswerFeedback {
        guard let current else { return AnswerFeedback(isCorrect: false, correctAnswer: "") }
        return record(isCorrect: choice == current.card.meaning)
    }

    /// 「わからない」・時間切れとして不正解と同じ扱いにする
    @discardableResult
    mutating func skip() -> AnswerFeedback {
        guard current != nil else { return AnswerFeedback(isCorrect: false, correctAnswer: "") }
        return record(isCorrect: false)
    }

    private mutating func record(isCorrect: Bool) -> AnswerFeedback {
        if let lastFeedback { return lastFeedback }
        let card = queue[position]
        if !isReview {
            let after = ScoreRule.apply(score: card.score, correct: isCorrect)
            changes.append(ScoreChange(cardID: card.id, term: card.term, before: card.score, after: after))
        }
        if isCorrect {
            correctCount += 1
        } else {
            wrongCards.append(card)
        }
        let feedback = AnswerFeedback(isCorrect: isCorrect, correctAnswer: card.meaning)
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
        let card = queue[index]
        let choices = ChoiceBuilder.choices(
            for: card,
            passageMeanings: passageMeanings,
            fallbackMeanings: fallbackMeanings,
            using: &rng
        )
        return QuizQuestion(card: card, choices: choices)
    }
}
