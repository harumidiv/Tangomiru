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
    和訳も解説も日本語で書いてください。原文から引用する英単語や英語の表現は、日本語の説明中に「」で示してください。
    説明は正確さを最優先にし、確信が持てない文法用語は使わないでください。
    """

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func analyze(_ sentence: String) async throws -> SentenceAnalysis {
        let session = LanguageModelSession(instructions: Self.instructions)
        let content = try await session.respond(
            to: Self.prompt(for: sentence),
            generating: GeneratedSentenceAnalysis.self
        ).content
        if SentenceAnalysisValidator.isJapaneseExplanation(content.explanation) {
            return SentenceAnalysis(translation: content.translation, explanation: content.explanation)
        }
        do {
            let explanation = try await explain(sentence, translation: content.translation)
            return SentenceAnalysis(translation: content.translation, explanation: explanation)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return SentenceAnalysis(translation: content.translation, explanation: "", isExplanationFailed: true)
        }
    }

    static func prompt(for sentence: String) -> String {
        "# 英文\n\(sentence)"
    }
}

@Generable
nonisolated struct GeneratedSentenceExplanation: Sendable {
    @Guide(description: "この文の構造・文法・表現のポイントを英語学習者向けに説明する日本語の文章（150文字以内）")
    var explanation: String
}

/// 和訳は別のモデル（PLaMo）が作り、ここでは解説だけを作る
extension FoundationModelsSentenceAnalyzer: SentenceExplainer {
    static let explanationInstructions = """
    あなたは日本人の英語学習者に英文法を教える先生です。
    与えられた英文1文とその日本語訳をもとに、その文の構造・文法・表現のポイントをやさしく説明してください。
    解説の本文は日本語で書いてください。原文から引用する英単語や英語の表現は、日本語の説明中に「」で示してください。
    説明は日本語訳と食い違わないようにしてください。
    説明は正確さを最優先にし、確信が持てない文法用語は使わないでください。
    """

    func explain(_ sentence: String, translation: String) async throws -> String {
        let prompt = Self.explanationPrompt(for: sentence, translation: translation)
        let explanation = try await generateExplanation(prompt)
        if SentenceAnalysisValidator.isJapaneseExplanation(explanation) { return explanation }
        let retry = try await generateExplanation(prompt + "\n\n英文の内容を日本語で解説してください。解説の本文には日本語の文を使ってください。")
        guard SentenceAnalysisValidator.isJapaneseExplanation(retry) else { throw ExplanationError.notJapanese }
        return retry
    }

    private enum ExplanationError: Error {
        case notJapanese
    }

    private func generateExplanation(_ prompt: String) async throws -> String {
        let session = LanguageModelSession(instructions: Self.explanationInstructions)
        return try await session.respond(
            to: prompt,
            generating: GeneratedSentenceExplanation.self
        ).content.explanation
    }

    static func explanationPrompt(for sentence: String, translation: String) -> String {
        "# 英文\n\(sentence)\n\n# 日本語訳\n\(translation)"
    }
}
