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
