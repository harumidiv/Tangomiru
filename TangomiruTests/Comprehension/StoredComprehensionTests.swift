import Foundation
import SwiftData
import Testing
@testable import Tangomiru

struct StoredComprehensionTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Passage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func question(_ tag: String) -> ComprehensionQuestion {
        ComprehensionQuestion(question: tag, choices: ["a", "b", "c", "d"], answerIndex: 2, evidence: tag == "q1" ? "ev" : nil)
    }

    @Test func savesQuestionsInOrder() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: true)
        context.insert(passage)
        passage.setComprehensionQuestions([question("q1"), question("q2"), question("q3")])
        try context.save()
        #expect(passage.comprehensionQuestions == [question("q1"), question("q2"), question("q3")])
    }

    @Test func replacingQuestionsRemovesOldOnes() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: true)
        context.insert(passage)
        passage.setComprehensionQuestions([question("old")])
        try context.save()
        passage.setComprehensionQuestions([question("new")])
        try context.save()
        #expect(passage.comprehensionQuestions.map(\.question) == ["new"])
        #expect(try context.fetchCount(FetchDescriptor<StoredComprehensionQuestion>()) == 1)
    }

    @Test func deletingPassageDeletesQuestions() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: true)
        context.insert(passage)
        passage.setComprehensionQuestions([question("q1")])
        try context.save()
        context.delete(passage)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<StoredComprehensionQuestion>()) == 0)
    }
}
