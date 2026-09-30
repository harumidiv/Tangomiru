nonisolated struct EnrichmentInput: Equatable, Sendable {
    let term: String
    let contextSentence: String
    let dictionaryMeaning: String
}

nonisolated struct EnrichedEntry: Equatable, Sendable {
    let term: String
    let meaning: String
    let distractors: [String]
}

nonisolated struct EnrichmentOutput: Equatable, Sendable {
    var words: [EnrichedEntry]
    /// 辞書で拾えなかった熟語
    var idioms: [EnrichedEntry]
}

/// 抽出結果に文脈訳・誤答・熟語を上乗せする（Foundation Models 実装とテスト用 Fake を差し替える）
nonisolated protocol VocabEnricher: Sendable {
    var isAvailable: Bool { get }
    func enrich(_ inputs: [EnrichmentInput], sentences: [String]) async throws -> EnrichmentOutput
}
