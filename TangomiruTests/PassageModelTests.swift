import Foundation
import SwiftData
import Testing
@testable import Tangomiru

struct PassageModelTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Passage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func extracted(_ term: String, at location: Int, length: Int) -> ExtractedItem {
        ExtractedItem(
            term: term, meaning: "\(term)の意味", distractors: ["誤"], contextSentence: "ctx",
            occurrences: [TextSpan(location: location, length: length)], source: .dictionary
        )
    }

    @Test func statsCountOnlyEnabledItems() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        let a = VocabItem(extracted: extracted("a", at: 0, length: 1))
        let b = VocabItem(extracted: extracted("b", at: 2, length: 1), isEnabled: false)
        a.score = 2
        b.score = 2
        passage.items = [a, b]
        #expect(passage.stats.total == 1)
        #expect(passage.stats.masteredRate == 1)
    }

    @Test func applyQuizResultUpdatesScoresAndDate() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        let item = VocabItem(extracted: extracted("a", at: 0, length: 1))
        passage.items = [item]
        let date = Date(timeIntervalSince1970: 1_000)
        passage.applyQuizResult([ScoreChange(cardID: item.uuid, term: "a", before: nil, after: 1)], at: date)
        #expect(item.score == 1)
        #expect(passage.lastStudiedAt == date)
    }

    @Test func deletingPassageDeletesItems() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        passage.items = [VocabItem(extracted: extracted("a", at: 0, length: 1))]
        try context.save()
        context.delete(passage)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<VocabItem>()) == 0)
    }

    @Test func quizCardUsesSurfaceFromBody() throws {
        let item = VocabItem(extracted: extracted("run", at: 8, length: 7))
        let card = item.quizCard(body: "She was running fast.")
        #expect(card.highlight == "running")
        #expect(card.id == item.uuid)
        #expect(card.distractors == ["誤"])
        #expect(card.score == nil)
    }

    @Test func quizCardFallsBackToTermWhenSpanIsInvalid() {
        let item = VocabItem(extracted: extracted("run", at: 100, length: 7))
        #expect(item.quizCard(body: "short").highlight == "run")
    }

    @Test func sortedItemsFollowFirstOccurrence() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: false)
        context.insert(passage)
        passage.items = [
            VocabItem(extracted: extracted("later", at: 10, length: 5)),
            VocabItem(extracted: extracted("first", at: 0, length: 5)),
        ]
        #expect(passage.sortedItems.map(\.term) == ["first", "later"])
    }

    @Test func addWordCreatesManualItemWithOccurrencesAndSentence() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "I like cats. Cats sleep a lot.", usedAI: false)
        context.insert(passage)
        let item = passage.addWord("Cats", meaning: "猫")
        #expect(passage.items.count == 1)
        #expect(item.term == "cats")
        #expect(item.meaning == "猫")
        #expect(item.source == .manual)
        #expect(item.isEnabled)
        #expect(item.occurrences == [TextSpan(location: 7, length: 4), TextSpan(location: 13, length: 4)])
        #expect(item.contextSentence == "I like cats.")
        #expect(passage.readingHighlights.count == 2)
    }

    @Test func addWordReenablesExistingItemInsteadOfDuplicating() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "abc", usedAI: false)
        context.insert(passage)
        let existing = VocabItem(extracted: extracted("abc", at: 0, length: 3), isEnabled: false)
        passage.items = [existing]
        let item = passage.addWord("ABC", meaning: "別の訳")
        #expect(passage.items.count == 1)
        #expect(item.uuid == existing.uuid)
        #expect(item.isEnabled)
        #expect(item.meaning == "abcの意味")
    }
}
