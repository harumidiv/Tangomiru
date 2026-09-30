import Foundation
import SwiftData
import Testing
@testable import Tangomiru

struct StoredSentenceAnalysisTests {
    private func makeContext() throws -> ModelContext {
        ModelContext(try ModelContainer(for: Passage.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
    }

    private func analysis(_ translation: String) -> SentenceAnalysis {
        SentenceAnalysis(translation: translation, explanation: "had to は過去の義務")
    }

    @Test func savesAndLoadsBySentence() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: true)
        context.insert(passage)
        passage.saveSentenceAnalysis(analysis("訳1"), for: "She left.")
        try context.save()
        #expect(passage.sentenceAnalyses == ["She left.": analysis("訳1")])
    }

    @Test func savingSameSentenceReplacesOld() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: true)
        context.insert(passage)
        passage.saveSentenceAnalysis(analysis("古い"), for: "She left.")
        try context.save()
        passage.saveSentenceAnalysis(analysis("新しい"), for: "She left.")
        try context.save()
        #expect(passage.sentenceAnalyses["She left."]?.translation == "新しい")
        #expect(try context.fetchCount(FetchDescriptor<StoredSentenceAnalysis>()) == 1)
    }

    @Test func deletingPassageDeletesAnalyses() throws {
        let context = try makeContext()
        let passage = Passage(title: "t", body: "b", usedAI: true)
        context.insert(passage)
        passage.saveSentenceAnalysis(analysis("訳"), for: "She left.")
        try context.save()
        context.delete(passage)
        try context.save()
        #expect(try context.fetchCount(FetchDescriptor<StoredSentenceAnalysis>()) == 0)
    }
}
