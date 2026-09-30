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
