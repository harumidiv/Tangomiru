import Foundation
import FoundationModels

@Generable
nonisolated struct GeneratedComprehensionQuestion: Sendable {
    @Guide(description: "本文の内容についての日本語の問題文")
    var question: String
    @Guide(description: "日本語の選択肢。本文に基づく正解が1つだけで、残りは本文と食い違うもっともらしい誤り", .count(4))
    var choices: [String]
    @Guide(description: "正解の選択肢の番号（0から3）", .range(0...3))
    var answerIndex: Int
    @Guide(description: "正解の根拠となる本文中の英文。本文からそのまま抜き出す")
    var evidence: String
}

@Generable
nonisolated struct GeneratedComprehensionSet: Sendable {
    @Guide(description: "内容理解の問題", .maximumCount(10))
    var questions: [GeneratedComprehensionQuestion]
}

nonisolated struct FoundationModelsComprehensionGenerator: ComprehensionQuestionGenerator {
    static let instructions = """
    あなたは日本人の英語学習者向けに、英文読解の確認問題を作る先生です。
    与えられた英文の本文を読み、内容をきちんと理解できたかを確かめる日本語の4択問題を作ってください。
    正解は必ず本文の内容だけから判断できるものにし、本文に書かれていないことを正解にしないでください。
    問題はそれぞれ本文の違う部分について作ってください。
    """

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func generate(from passage: String, count: Int) async throws -> [ComprehensionQuestion] {
        let session = LanguageModelSession(instructions: Self.instructions)
        let content = try await session.respond(
            to: Self.prompt(passage: passage, count: count),
            generating: GeneratedComprehensionSet.self
        ).content
        return content.questions.map {
            ComprehensionQuestion(question: $0.question, choices: $0.choices, answerIndex: $0.answerIndex, evidence: $0.evidence)
        }
    }

    static func prompt(passage: String, count: Int) -> String {
        "# 本文\n\(passage)\n# 作る問題の数\n\(count)問"
    }
}
