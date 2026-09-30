import Foundation

/// 1文の和訳と解説（AI が作り、表示前に SentenceAnalysisValidator で検査する）
nonisolated struct SentenceAnalysis: Codable, Equatable, Sendable {
    var translation: String
    /// 文の構造・文法・表現のポイントを説明する日本語の文章
    var explanation: String
}

/// 1文の和訳と解説を作る（Foundation Models 実装とテスト用 Fake を差し替える）
nonisolated protocol SentenceAnalyzer: Sendable {
    var isAvailable: Bool { get }
    func analyze(_ sentence: String) async throws -> SentenceAnalysis
}

nonisolated enum SentenceAnalysisValidator {
    /// 和訳が無ければ nil。解説は空でもよい
    static func validated(_ analysis: SentenceAnalysis) -> SentenceAnalysis? {
        let translation = analysis.translation.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !translation.isEmpty else { return nil }
        return SentenceAnalysis(
            translation: translation,
            explanation: analysis.explanation.trimmingCharacters(in: .whitespacesAndNewlines)
        )
    }
}
