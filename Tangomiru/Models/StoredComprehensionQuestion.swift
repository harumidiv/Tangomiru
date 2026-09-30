import Foundation
import SwiftData

/// 抽出時（または初回のクイズ時）に作って保存した内容理解の問題
@Model
final class StoredComprehensionQuestion {
    var order: Int
    var question: String
    var choices: [String]
    var answerIndex: Int
    var evidence: String?
    var passage: Passage?

    init(order: Int, question: ComprehensionQuestion) {
        self.order = order
        self.question = question.question
        self.choices = question.choices
        self.answerIndex = question.answerIndex
        self.evidence = question.evidence
    }

    var value: ComprehensionQuestion {
        ComprehensionQuestion(question: question, choices: choices, answerIndex: answerIndex, evidence: evidence)
    }
}
