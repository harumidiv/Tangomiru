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
    @Relationship(deleteRule: .cascade, inverse: \StoredSentenceAnalysis.passage)
    var storedSentenceAnalyses: [StoredSentenceAnalysis] = []

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

    /// 英文 → 保存済みの和訳と解説
    var sentenceAnalyses: [String: SentenceAnalysis] {
        Dictionary(storedSentenceAnalyses.map { ($0.sentence, $0.value) }, uniquingKeysWith: { first, _ in first })
    }

    func saveSentenceAnalysis(_ analysis: SentenceAnalysis, for sentence: String) {
        for old in storedSentenceAnalyses where old.sentence == sentence { modelContext?.delete(old) }
        storedSentenceAnalyses.removeAll { $0.sentence == sentence }
        storedSentenceAnalyses.append(StoredSentenceAnalysis(sentence: sentence, analysis: analysis))
    }

    /// term（大文字小文字は区別しない）に一致する語
    func item(matching term: String) -> VocabItem? {
        let key = term.lowercased()
        return items.first { $0.term.lowercased() == key }
    }

    /// タップした語を単語帳に加える。同じ語がオフになっていればオンに戻す
    @discardableResult
    func addWord(_ word: String, meaning: String) -> VocabItem {
        if let existing = item(matching: word) {
            existing.isEnabled = true
            return existing
        }
        let term = word.lowercased()
        let occurrences = TextSearch.occurrences(of: term, in: body)
        let sentence = occurrences.first.flatMap { span in
            SentenceSplitter.slices(in: body).first { $0.span.location <= span.location && span.end <= $0.span.end }?.text
        } ?? ""
        let formatted = MeaningFormatter.single(meaning)
        let item = VocabItem(extracted: ExtractedItem(
            term: term,
            meaning: formatted.isEmpty ? meaning : formatted,
            distractors: [],
            contextSentence: sentence,
            occurrences: occurrences,
            source: .manual
        ))
        items.append(item)
        return item
    }

    func applyQuizResult(_ changes: [ScoreChange], at date: Date = .now) {
        let itemsByID = Dictionary(items.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        for change in changes {
            itemsByID[change.cardID]?.score = change.after
        }
        lastStudiedAt = date
    }
}
