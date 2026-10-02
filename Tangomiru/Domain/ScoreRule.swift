/// 習得スコアの更新ルール。nil=未学習, -1=超苦手, 0=苦手, 1=うろ覚え, 2=覚えた
nonisolated enum ScoreRule {
    static let minScore = -1
    static let maxScore = 2
    /// 未学習の語にこれ以内で正解したら、すぐに「覚えた」にする
    static let instantMastery: Duration = .seconds(2)
    /// これ以上かかった正解は、うろ覚えとみなして1つ下げる
    static let slowAnswer: Duration = .seconds(8)

    /// elapsed は解答までにかかった時間（nil なら時間を考慮しない）
    static func apply(score: Int?, correct: Bool, elapsed: Duration? = nil) -> Int {
        if correct, let elapsed {
            if score == nil && elapsed <= instantMastery { return maxScore }
            if elapsed >= slowAnswer { return max((score ?? 1) - 1, minScore) }
        }
        guard let score else { return correct ? 1 : 0 }
        return min(max(score + (correct ? 1 : -1), minScore), maxScore)
    }
}
