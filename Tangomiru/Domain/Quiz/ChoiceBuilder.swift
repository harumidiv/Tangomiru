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
