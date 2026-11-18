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

    @Test func repairsCrossReferenceMeaning() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "We analyze data.", usedAI: false)
        context.insert(passage)
        let analyze = item("analyze", meaning: "=analyze", distractors: ["=colour", "走る"], source: .dictionary, at: 3, length: 7)
        passage.items = [analyze]
        let dictionary = FakeDictionary(entries: ["analyze": "分析する"])
        MeaningMigration.migrate(passage, tokenizer: Tokenizer(), dictionary: dictionary)
        #expect(analyze.meaning == "分析する")
        #expect(analyze.distractors == ["走る"])
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

    @Test func correctsKnownSavedTranslationsAndPreservesOtherMeaningsAndScores() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "Clients trust our global network.", usedAI: false)
        context.insert(passage)
        let clients = item("Clients", meaning: "弁護", distractors: ["顧客", "店舗"], source: .dictionary, at: 0, length: 7)
        let global = item("global", meaning: "球の", source: .dictionary, at: 18, length: 6)
        let other = item("global", meaning: "全体的な", source: .dictionary, at: 18, length: 6)
        clients.score = 2
        passage.items = [clients, global, other]

        let dictionary = try EJDictionary.loadBundled()
        MeaningMigration.migrate(passage, tokenizer: Tokenizer(), dictionary: dictionary)
        #expect(clients.meaning == "顧客")
        #expect(clients.distractors == ["店舗"])
        #expect(clients.score == 2)
        #expect(global.meaning == "世界的な")
        #expect(other.meaning == "全体的な")
    }

    @Test func detectsOldFormat() {
        #expect(MeaningMigration.needsMigration("走る,駆ける / 急ぐ"))
        #expect(MeaningMigration.needsMigration("〈人が〉急ぐ"))
        #expect(!MeaningMigration.needsMigration("走る"))
        #expect(MeaningMigration.needsMigration("=analyze"))
        #expect(MeaningMigration.needsMigration("answer"))
    }
}
