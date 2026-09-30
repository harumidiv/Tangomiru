import Foundation

/// 1文の文法解説（AI が作り、表示前に SentenceAnalysisValidator で検査する）
nonisolated struct SentenceAnalysis: Equatable, Sendable {
    var translation: String
    /// 文の構造（主語・動詞・目的語・補語・修飾語など）
    var parts: [SentencePart]
    var points: [GrammarPoint]
    var quiz: GrammarQuiz?
}

nonisolated struct SentencePart: Equatable, Sendable {
    var role: String
    var text: String
}

nonisolated struct GrammarPoint: Equatable, Sendable {
    var title: String
    var explanation: String
}

nonisolated struct GrammarQuiz: Equatable, Sendable {
    var question: String
    var choices: [String]
    var answerIndex: Int
}

/// 1文の和訳・構造・文法ポイント・確認クイズを作る（Foundation Models 実装とテスト用 Fake を差し替える）
nonisolated protocol SentenceAnalyzer: Sendable {
    var isAvailable: Bool { get }
    func analyze(_ sentence: String) async throws -> SentenceAnalysis
}

nonisolated enum SentenceAnalysisValidator {
    static let maxPoints = 3
    static let choiceCount = 4

    /// 和訳が無ければ nil。英文に無い部分を指す構造・空の文法ポイント・壊れたクイズは取り除く
    static func validated(_ analysis: SentenceAnalysis, sentence: String) -> SentenceAnalysis? {
        let translation = trimmed(analysis.translation)
        guard !translation.isEmpty else { return nil }
        let parts = analysis.parts.compactMap { part -> SentencePart? in
            let role = trimmed(part.role)
            let text = trimmed(part.text)
            guard !role.isEmpty, !text.isEmpty, sentence.range(of: text, options: .caseInsensitive) != nil else { return nil }
            return SentencePart(role: role, text: text)
        }
        let points = analysis.points
            .map { GrammarPoint(title: trimmed($0.title), explanation: trimmed($0.explanation)) }
            .filter { !$0.title.isEmpty && !$0.explanation.isEmpty }
        return SentenceAnalysis(
            translation: translation,
            parts: parts,
            points: Array(points.prefix(maxPoints)),
            quiz: analysis.quiz.flatMap(validatedQuiz)
        )
    }

    private static func validatedQuiz(_ quiz: GrammarQuiz) -> GrammarQuiz? {
        let question = trimmed(quiz.question)
        let choices = quiz.choices.map(trimmed)
        guard !question.isEmpty,
              choices.count == choiceCount,
              !choices.contains(where: \.isEmpty),
              Set(choices).count == choiceCount,
              choices.indices.contains(quiz.answerIndex) else { return nil }
        return GrammarQuiz(question: question, choices: choices, answerIndex: quiz.answerIndex)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
