import Foundation

/// 本文の内容を問う4択問題（AI が作り、表示前に ComprehensionValidator で検査する）
nonisolated struct ComprehensionQuestion: Hashable, Sendable {
    var question: String
    var choices: [String]
    var answerIndex: Int
    /// 答えの根拠になる本文中の英文
    var evidence: String?
}

/// 本文の一部から内容理解の問題を作る（Foundation Models 実装とテスト用 Fake を差し替える）
nonisolated protocol ComprehensionQuestionGenerator: Sendable {
    var isAvailable: Bool { get }
    func generate(from passage: String, count: Int) async throws -> [ComprehensionQuestion]
    /// 文章全体の要旨を問う問題（「この文章は主に何について書かれていますか？」など）
    func generateGist(from passage: String) async throws -> ComprehensionQuestion
}

nonisolated enum ComprehensionValidator {
    static let choiceCount = 4

    /// 壊れた問題は nil。根拠が本文に無ければ根拠だけ外す
    static func validated(_ question: ComprehensionQuestion, passage: String) -> ComprehensionQuestion? {
        let text = trimmed(question.question)
        let choices = question.choices.map(trimmed)
        guard !text.isEmpty,
              choices.count == choiceCount,
              !choices.contains(where: \.isEmpty),
              Set(choices).count == choiceCount,
              choices.indices.contains(question.answerIndex) else { return nil }
        let evidence = question.evidence.map(trimmed).flatMap { evidence in
            !evidence.isEmpty && passage.range(of: evidence, options: .caseInsensitive) != nil ? evidence : nil
        }
        return ComprehensionQuestion(question: text, choices: choices, answerIndex: question.answerIndex, evidence: evidence)
    }

    private static func trimmed(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated enum ComprehensionPlanner {
    static let minQuestions = 3
    static let maxQuestions = 10
    /// 端末内 AI に一度に渡す本文の目安（文字数）
    static let maxChunkLength = 1_200

    /// 文の数の半分を目安に 3〜10問
    static func questionCount(sentenceCount: Int) -> Int {
        min(max((sentenceCount + 1) / 2, minQuestions), maxQuestions)
    }

    /// 文を区切らないように、maxLength 以内でまとめる（1文だけで超える場合はその文だけの塊にする）
    static func chunks(of sentences: [String], maxLength: Int) -> [String] {
        var chunks: [String] = []
        var current = ""
        for sentence in sentences {
            let candidate = current.isEmpty ? sentence : current + " " + sentence
            if candidate.count <= maxLength || current.isEmpty {
                current = candidate
            } else {
                chunks.append(current)
                current = sentence
            }
        }
        if !current.isEmpty { chunks.append(current) }
        return chunks
    }

    /// 問題を本文全体に散らばるように各チャンクへ割り振る
    static func questionsPerChunk(total: Int, chunkCount: Int) -> [Int] {
        guard chunkCount > 0 else { return [] }
        var counts = Array(repeating: 0, count: chunkCount)
        for question in 0..<total {
            counts[question * chunkCount / total] += 1
        }
        return counts
    }
}
