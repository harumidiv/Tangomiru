/// 1問あたりの制限時間
nonisolated enum QuizCountdown {
    static let limit: Duration = .seconds(10)
    /// 解答（または時間切れ）後、次の問題へ自動で進むまでの時間
    static let revealDuration: Duration = .seconds(1)

    /// 残り時間の割合（1 → 0）
    static func remainingFraction(elapsed: Duration) -> Double {
        let ratio = elapsed / limit
        return min(max(1 - ratio, 0), 1)
    }
}
