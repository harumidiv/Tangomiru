import Foundation
import SwiftData

@Model
final class Passage {
    var title: String
    var body: String
    var createdAt: Date
    var lastStudiedAt: Date?
    /// 抽出時に AI の上乗せが行われたか
    var usedAI: Bool
    @Relationship(deleteRule: .cascade, inverse: \VocabItem.passage)
    var items: [VocabItem] = []
    @Relationship(deleteRule: .cascade, inverse: \StoredComprehensionQuestion.passage)
    var storedComprehension: [StoredComprehensionQuestion] = []

    init(title: String, body: String, usedAI: Bool, createdAt: Date = .now) {
        self.title = title
        self.body = body
        self.usedAI = usedAI
        self.createdAt = createdAt
    }
}

extension Passage {
    var enabledItems: [VocabItem] { items.filter(\.isEnabled) }

    var sortedItems: [VocabItem] { items.sorted { $0.firstLocation < $1.firstLocation } }

    var stats: MasteryStats { MasteryStats(scores: enabledItems.map(\.score)) }

    var quizCards: [QuizCard] { enabledItems.map { $0.quizCard(body: body) } }

    var comprehensionQuestions: [ComprehensionQuestion] {
        storedComprehension.sorted { $0.order < $1.order }.map(\.value)
    }

    func setComprehensionQuestions(_ questions: [ComprehensionQuestion]) {
        for old in storedComprehension { modelContext?.delete(old) }
        storedComprehension = questions.enumerated().map { StoredComprehensionQuestion(order: $0.offset, question: $0.element) }
    }

    func applyQuizResult(_ changes: [ScoreChange], at date: Date = .now) {
        let itemsByID = Dictionary(items.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        for change in changes {
            itemsByID[change.cardID]?.score = change.after
        }
        lastStudiedAt = date
    }
}
