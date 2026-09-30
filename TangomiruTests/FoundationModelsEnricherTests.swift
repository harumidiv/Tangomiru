import Testing
@testable import Tangomiru

struct FoundationModelsEnricherTests {
    @Test func promptListsSentencesAndTerms() {
        let prompt = FoundationModelsEnricher.prompt(
            inputs: [EnrichmentInput(term: "abyss", contextSentence: "Into the abyss.", dictionaryMeaning: "深淵")],
            sentences: ["Into the abyss."]
        )
        #expect(prompt == """
        # 例文
        - Into the abyss.
        # 語（見出し語: 辞書の訳）
        - abyss: 深淵
        """)
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsEnricher().isAvailable
    }
}
