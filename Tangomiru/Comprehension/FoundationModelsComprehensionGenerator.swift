import Foundation
import FoundationModels

@Generable
nonisolated struct GeneratedComprehensionQuestion: Sendable {
    @Guide(description: "本文の内容について尋ねる日本語の問題文。英文を書き写さず、日本語の疑問文にする（例: 停電のあと人々はどうしましたか？）")
    var question: String
    @Guide(description: "本文の内容だけから分かる正しい答え。日本語で短く書く")
    var correctAnswer: String
    @Guide(description: "本文の内容と食い違う、もっともらしい誤りの答え。日本語で短く書き、正しい答えとも互いにも違う内容にする", .count(3))
    var wrongAnswers: [String]
    @Guide(description: "正しい答えの根拠となる本文中の英文1文。本文からそのまま抜き出す")
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
    問題文と選択肢は必ず日本語で書き、本文の英文をそのまま書き写してはいけません。
    正しい答えは本文の内容だけから判断できるものにし、誤りの答え3つは正しい答えとも互いにも違う内容にしてください。
    問題はそれぞれ本文の違う部分について作ってください。
    例:
    本文: Tom missed the bus, so he walked to school.
    問題: トムはどうやって学校へ行きましたか？
    正しい答え: 歩いて行った
    誤りの答え: バスで行った / 自転車で行った / 車で送ってもらった
    根拠: Tom missed the bus, so he walked to school.
    """

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func generate(from passage: String, count: Int) async throws -> [ComprehensionQuestion] {
        let session = LanguageModelSession(instructions: Self.instructions)
        let content = try await session.respond(
            to: Self.prompt(passage: passage, count: count),
            generating: GeneratedComprehensionSet.self
        ).content
        var rng = SeededRandom()
        return content.questions.map {
            Self.question(text: $0.question, correct: $0.correctAnswer, wrong: $0.wrongAnswers, evidence: $0.evidence, using: &rng)
        }
    }

    static func question(text: String, correct: String, wrong: [String], evidence: String, using rng: inout SeededRandom) -> ComprehensionQuestion {
        let (choices, answerIndex) = MultipleChoice.shuffled(correct: correct, wrong: wrong, using: &rng)
        return ComprehensionQuestion(question: text, choices: choices, answerIndex: answerIndex, evidence: evidence)
    }

    func generateGist(from passage: String) async throws -> ComprehensionQuestion {
        let session = LanguageModelSession(instructions: Self.instructions)
        let content = try await session.respond(
            to: Self.gistPrompt(passage: passage),
            generating: GeneratedComprehensionQuestion.self
        ).content
        var rng = SeededRandom()
        return Self.question(text: content.question, correct: content.correctAnswer, wrong: content.wrongAnswers, evidence: content.evidence, using: &rng)
    }

    static func gistPrompt(passage: String) -> String {
        "# 本文\n\(passage)\n# 作る問題\n文章全体が主に何について書かれているかを問う要旨の問題を1問（例: この文章は主に何について書かれていますか？）"
    }

    static func prompt(passage: String, count: Int) -> String {
        "# 本文\n\(passage)\n# 作る問題の数\n\(count)問"
    }
}
