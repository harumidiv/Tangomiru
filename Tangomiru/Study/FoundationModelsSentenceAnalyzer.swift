import Foundation
import FoundationModels

@Generable
nonisolated struct GeneratedSentencePart: Sendable {
    @Guide(description: "文の中での役割。主語・動詞・目的語・補語・修飾語のいずれか")
    var role: String
    @Guide(description: "その役割にあたる部分。英文からそのまま抜き出す")
    var text: String
}

@Generable
nonisolated struct GeneratedGrammarPoint: Sendable {
    @Guide(description: "文法ポイントの名前（例: 過去完了、関係代名詞 who、to 不定詞の副詞的用法）")
    var title: String
    @Guide(description: "英語学習者向けの短い日本語の説明（60文字以内）")
    var explanation: String
}

@Generable
nonisolated struct GeneratedGrammarQuiz: Sendable {
    @Guide(description: "この文の文法ポイントを確かめる日本語の問題文")
    var question: String
    @Guide(description: "選択肢。1つだけが正解で、残りはもっともらしい誤り", .count(4))
    var choices: [String]
    @Guide(description: "正解の選択肢の番号（0から3）", .range(0...3))
    var answerIndex: Int
}

@Generable
nonisolated struct GeneratedSentenceAnalysis: Sendable {
    @Guide(description: "英文の自然な日本語訳")
    var translation: String
    @Guide(description: "文の構造。英文に出てくる順")
    var parts: [GeneratedSentencePart]
    @Guide(description: "この文で学べる文法ポイント", .maximumCount(3))
    var points: [GeneratedGrammarPoint]
    @Guide(description: "文法ポイントの確認問題")
    var quiz: GeneratedGrammarQuiz
}

nonisolated struct FoundationModelsSentenceAnalyzer: SentenceAnalyzer {
    static let instructions = """
    あなたは日本人の英語学習者に英文法を教える先生です。
    与えられた英文1文について、自然な日本語訳、文の構造（主語・動詞・目的語・補語・修飾語）、
    この文で学べる重要な文法ポイント、そのポイントを確かめる4択問題を作ってください。
    説明は正確さを最優先にし、確信が持てない文法用語は使わないでください。
    """

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func analyze(_ sentence: String) async throws -> SentenceAnalysis {
        let session = LanguageModelSession(instructions: Self.instructions)
        let content = try await session.respond(
            to: Self.prompt(for: sentence),
            generating: GeneratedSentenceAnalysis.self
        ).content
        return SentenceAnalysis(
            translation: content.translation,
            parts: content.parts.map { SentencePart(role: $0.role, text: $0.text) },
            points: content.points.map { GrammarPoint(title: $0.title, explanation: $0.explanation) },
            quiz: GrammarQuiz(question: content.quiz.question, choices: content.quiz.choices, answerIndex: content.quiz.answerIndex)
        )
    }

    static func prompt(for sentence: String) -> String {
        "# 英文\n\(sentence)"
    }
}
