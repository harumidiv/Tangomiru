/// 単語クイズの出題範囲。おまかせは出題ON の全語、それ以外は習得状態で絞り込む
nonisolated enum QuizScope: String, CaseIterable, Identifiable, Sendable {
    case auto
    case unseen
    case veryWeak
    case weak
    case vague
    case mastered

    var id: String { rawValue }

    var state: MasteryState? {
        switch self {
        case .auto: nil
        case .unseen: .unseen
        case .veryWeak: .veryWeak
        case .weak: .weak
        case .vague: .vague
        case .mastered: .mastered
        }
    }

    var label: String { state?.label ?? "おまかせ" }

    func cards(from cards: [QuizCard]) -> [QuizCard] {
        guard let state else { return cards }
        return cards.filter { MasteryState(score: $0.score) == state }
    }

    func count(in stats: MasteryStats) -> Int {
        state.map(stats.count) ?? stats.total
    }
}
