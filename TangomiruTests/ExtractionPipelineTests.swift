import Testing
@testable import Tangomiru

struct ExtractionPipelineTests {
    nonisolated static let words = [
        "abyss", "ballad", "cactus", "dagger", "ember", "falcon", "glacier", "hamlet", "iceberg", "jungle",
        "kernel", "lantern", "meadow", "nectar", "orchid", "pebble", "quartz", "riddle", "saddle", "tundra",
    ]
    nonisolated static let body = "I saw " + words.joined(separator: ", ") + "."

    let dictionary = FakeDictionary(entries: Dictionary(uniqueKeysWithValues: words.map { ($0, "\($0)の辞書訳") }))

    private func pipeline(_ enricher: (any VocabEnricher)?) -> ExtractionPipeline {
        ExtractionPipeline(extractor: DictionaryExtractor(dictionary: dictionary, basicWords: []), enricher: enricher)
    }

    nonisolated private static func aiOutput(for inputs: [EnrichmentInput]) -> EnrichmentOutput {
        EnrichmentOutput(
            words: inputs.map { EnrichedEntry(term: $0.term, meaning: "\($0.term)の文脈訳", distractors: ["x", "y", "z", "\($0.term)の文脈訳"]) },
            idioms: []
        )
    }

    @Test func withoutEnricherUsesDictionary() async {
        let result = await pipeline(nil).run(Self.body)
        #expect(!result.usedAI)
        #expect(result.items.map(\.term) == Self.words)
        #expect(result.items[0].meaning == "abyssの辞書訳")
    }

    @Test func unavailableEnricherIsNotCalled() async {
        let enricher = FakeEnricher(isAvailable: false) { _, _ in
            Issue.record("unavailable enricher was called")
            return EnrichmentOutput(words: [], idioms: [])
        }
        let result = await pipeline(enricher).run(Self.body)
        #expect(!result.usedAI)
    }

    @Test func appliesAIMeaningsAndDistractors() async {
        let result = await pipeline(FakeEnricher { inputs, _ in Self.aiOutput(for: inputs) }).run(Self.body)
        #expect(result.usedAI)
        #expect(result.items[0].meaning == "abyssの文脈訳")
        #expect(result.items[0].distractors == ["x", "y", "z"])
        #expect(result.items[0].source == .dictionary)
    }

    @Test func splitsIntoChunksOfFifteen() async {
        let recorder = CallRecorder()
        let enricher = FakeEnricher { inputs, sentences in
            recorder.record(inputs.map(\.term))
            #expect(sentences == [Self.body])
            return Self.aiOutput(for: inputs)
        }
        _ = await pipeline(enricher).run(Self.body)
        #expect(recorder.calls.map(\.count) == [15, 5])
    }

    @Test func failedChunkFallsBackToDictionary() async {
        let enricher = FakeEnricher { inputs, _ in
            if inputs.first?.term == "abyss" { throw FakeError() }
            return Self.aiOutput(for: inputs)
        }
        let result = await pipeline(enricher).run(Self.body)
        #expect(result.usedAI)
        #expect(result.items[0].meaning == "abyssの辞書訳")
        #expect(result.items[19].meaning == "tundraの文脈訳")
    }

    @Test func allChunksFailingMeansDictionaryMode() async {
        let result = await pipeline(FakeEnricher { _, _ in throw FakeError() }).run(Self.body)
        #expect(!result.usedAI)
        #expect(result.items.count == 20)
    }

    @Test func addsIdiomsFoundInTextOnly() async {
        let body = "They gave up on the abyss."
        let enricher = FakeEnricher { inputs, _ in
            EnrichmentOutput(words: [], idioms: [
                EnrichedEntry(term: "gave up", meaning: "諦めた", distractors: ["始めた", "諦めた", "続けた"]),
                EnrichedEntry(term: "look forward to", meaning: "楽しみにする", distractors: []),
                EnrichedEntry(term: "Abyss", meaning: "重複", distractors: []),
            ])
        }
        let result = await pipeline(enricher).run(body)
        #expect(result.items.map(\.term) == ["gave up", "abyss"])
        let idiom = result.items[0]
        #expect(idiom.source == .ai)
        #expect(idiom.meaning == "諦めた")
        #expect(idiom.distractors == ["始めた", "続けた"])
        #expect(idiom.occurrences == [TextSpan(location: 5, length: 7)])
        #expect(idiom.contextSentence == body)
        #expect(result.items[1].meaning == "abyssの辞書訳")
    }

    @Test func cancelledRunSkipsAIEnrichment() async {
        let recorder = CallRecorder()
        let enricher = FakeEnricher { inputs, _ in
            recorder.record(inputs.map(\.term))
            return Self.aiOutput(for: inputs)
        }
        let pipeline = pipeline(enricher)
        let task = Task { await pipeline.run(Self.body) }
        task.cancel()
        let result = await task.value
        #expect(recorder.calls.isEmpty)
        #expect(!result.usedAI)
        #expect(result.items.count == 20)
    }

    @Test func emptyTextGivesNoItems() async {
        let result = await pipeline(FakeEnricher { inputs, _ in Self.aiOutput(for: inputs) }).run("the a an")
        #expect(result.items.isEmpty)
        #expect(!result.usedAI)
    }
}
