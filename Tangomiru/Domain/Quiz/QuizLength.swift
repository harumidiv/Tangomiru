nonisolated enum QuizLength: Int, CaseIterable, Identifiable, Sendable {
    case ten = 10
    case twenty = 20
    case all = 0

    var id: Int { rawValue }

    /// nil は全問
    var limit: Int? { self == .all ? nil : rawValue }

    var label: String { self == .all ? "全問" : "\(rawValue)問" }
}
