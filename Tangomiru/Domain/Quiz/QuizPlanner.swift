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
