/// 習得スコアの更新ルール。nil=未学習, -1=超苦手, 0=苦手, 1=うろ覚え, 2=覚えた
nonisolated enum ScoreRule {
    static let minScore = -1
    static let maxScore = 2

    static func apply(score: Int?, correct: Bool) -> Int {
        guard let score else { return correct ? 1 : 0 }
        return min(max(score + (correct ? 1 : -1), minScore), maxScore)
    }
}
