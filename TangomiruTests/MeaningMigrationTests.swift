import Foundation
import SwiftData
import Testing
@testable import Tangomiru

struct MeaningMigrationTests {
    let dictionary = FakeDictionary(entries: ["run": "走る", "run#noun": "走ること"])

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Passage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func item(_ term: String, meaning: String, distractors: [String] = [], source: ItemSource, at location: Int, length: Int) -> VocabItem {
        VocabItem(extracted: ExtractedItem(
            term: term, meaning: meaning, distractors: distractors, contextSentence: "ctx",
            occurrences: [TextSpan(location: location, length: length)], source: source
        ))
    }

    @Test func recomputesDictionaryMeaningUsingPartOfSpeechInBody() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "It was a long run.", usedAI: false)
        context.insert(passage)
        let run = item("run", meaning: "走る,駆ける / 急ぐ,突進する", source: .dictionary, at: 14, length: 3)
        passage.items = [run]
        MeaningMigration.migrate(passage, tokenizer: Tokenizer(), dictionary: dictionary)
        #expect(run.meaning == "走ること")
    }

    @Test func simplifiesAIMeaningAndDistractors() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "gave up", usedAI: true)
        context.insert(passage)
        let idiom = item("gave up", meaning: "諦めた（過去形）、断念した", distractors: ["始めた（開始）", "続けた"], source: .ai, at: 0, length: 7)
        passage.items = [idiom]
        MeaningMigration.migrate(passage, tokenizer: Tokenizer(), dictionary: dictionary)
        #expect(idiom.meaning == "諦めた")
        #expect(idiom.distractors == ["始めた", "続けた"])
    }

    @Test func leavesAlreadySimpleMeaningsUntouched() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "It was a long run.", usedAI: false)
        context.insert(passage)
        let run = item("run", meaning: "走る", source: .dictionary, at: 14, length: 3)
        passage.items = [run]
        MeaningMigration.migrate(passage, tokenizer: Tokenizer(), dictionary: dictionary)
        #expect(run.meaning == "走る")
    }

    @Test func detectsOldFormat() {
        #expect(MeaningMigration.needsMigration("走る,駆ける / 急ぐ"))
        #expect(MeaningMigration.needsMigration("〈人が〉急ぐ"))
        #expect(!MeaningMigration.needsMigration("走る"))
    }
}
