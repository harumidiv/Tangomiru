import Foundation
import FoundationModels

@Generable
nonisolated struct GeneratedSentenceAnalysis: Sendable {
    @Guide(description: "英文の自然な日本語訳")
    var translation: String
    @Guide(description: "この文の構造・文法・表現のポイントを英語学習者向けに説明する日本語の文章（150文字以内）")
    var explanation: String
}

nonisolated struct FoundationModelsSentenceAnalyzer: SentenceAnalyzer {
    static let instructions = """
    あなたは日本人の英語学習者に英文法を教える先生です。
    与えられた英文1文について、自然な日本語訳と、その文の構造・文法・表現のポイントをやさしく説明してください。
    説明は正確さを最優先にし、確信が持てない文法用語は使わないでください。
    """

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func analyze(_ sentence: String) async throws -> SentenceAnalysis {
        let session = LanguageModelSession(instructions: Self.instructions)
        let content = try await session.respond(
            to: Self.prompt(for: sentence),
            generating: GeneratedSentenceAnalysis.self
        ).content
        return SentenceAnalysis(translation: content.translation, explanation: content.explanation)
    }

    static func prompt(for sentence: String) -> String {
        "# 英文\n\(sentence)"
    }
}
