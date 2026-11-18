import Testing
@testable import Tangomiru

struct FoundationModelsEnricherTests {
    @Test func promptLinksEachTermToItsSentence() {
        let prompt = FoundationModelsEnricher.prompt(
            inputs: [
                EnrichmentInput(term: "global", contextSentence: "Our global network.", suggestedMeaning: "世界的な"),
                EnrichmentInput(term: "client", contextSentence: "She defended her clients.", suggestedMeaning: "依頼人", keepsSuggestedMeaning: true),
            ],
            sentences: ["She defended her clients.", "Our global network."]
        )
        #expect(prompt == """
        # 例文
        1. She defended her clients.
        2. Our global network.
        # 語（見出し語: 訳、対応する例文番号）
        - global: 世界的な（例文2）
        - client: PLaMoの訳 依頼人（例文1）
        """)
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsEnricher().isAvailable
    }
}
