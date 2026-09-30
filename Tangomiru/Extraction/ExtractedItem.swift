nonisolated enum ItemSource: String, Codable, Hashable, Sendable {
    case dictionary
    case ai
}

/// 抽出結果（保存前の値型）
nonisolated struct ExtractedItem: Hashable, Sendable {
    var term: String
    var meaning: String
    var distractors: [String]
    var contextSentence: String
    var occurrences: [TextSpan]
    var source: ItemSource

    var firstLocation: Int { occurrences.first?.location ?? .max }
}
