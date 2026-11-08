import Testing
@testable import Tangomiru

struct TranslateThenExplainAnalyzerTests {
    private static let fallback = FakeSentenceAnalyzer { _ in
        SentenceAnalysis(translation: "まとめて作った訳", explanation: "まとめて作った解説")
    }
    private static let explainer = FakeSentenceExplainer { _, translation in "「\(translation)」の解説" }

    @Test func translatesWithTranslatorAndExplainsThatTranslation() async throws {
        let analyzer = TranslateThenExplainAnalyzer(
            translator: FakeSentenceTranslator { _ in "彼女は早く帰らなければならなかった。" },
            explainer: Self.explainer,
            fallback: Self.fallback
        )
        let analysis = try await analyzer.analyze("She had to leave early.")
        #expect(analysis == SentenceAnalysis(
            translation: "彼女は早く帰らなければならなかった。",
            explanation: "「彼女は早く帰らなければならなかった。」の解説"
        ))
    }

    @Test func usesFallbackWhenTranslatorIsUnavailable() async throws {
        let analyzer = TranslateThenExplainAnalyzer(
            translator: FakeSentenceTranslator(isAvailable: false) { _ in "使われない訳" },
            explainer: Self.explainer,
            fallback: Self.fallback
        )
        #expect(try await analyzer.analyze("Hi.").translation == "まとめて作った訳")
    }

    @Test func usesFallbackWhenTranslatorFails() async throws {
        let analyzer = TranslateThenExplainAnalyzer(
            translator: FakeSentenceTranslator { _ in throw FakeError() },
            explainer: Self.explainer,
            fallback: Self.fallback
        )
        #expect(try await analyzer.analyze("Hi.").translation == "まとめて作った訳")
    }

    @Test func usesFallbackWhenTranslationIsBlank() async throws {
        let analyzer = TranslateThenExplainAnalyzer(
            translator: FakeSentenceTranslator { _ in "  \n" },
            explainer: Self.explainer,
            fallback: Self.fallback
        )
        #expect(try await analyzer.analyze("Hi.").translation == "まとめて作った訳")
    }

    @Test func keepsTranslationWhenExplanationFails() async throws {
        let analyzer = TranslateThenExplainAnalyzer(
            translator: FakeSentenceTranslator { _ in "訳" },
            explainer: FakeSentenceExplainer { _, _ in throw FakeError() },
            fallback: Self.fallback
        )
        #expect(try await analyzer.analyze("Hi.") == SentenceAnalysis(translation: "訳", explanation: "", isExplanationFailed: true))
    }

    @Test func returnsTranslationOnlyWhenExplainerIsUnavailable() async throws {
        let unavailableFallback = FakeSentenceAnalyzer(isAvailable: false) { _ in throw FakeError() }
        let analyzer = TranslateThenExplainAnalyzer(
            translator: FakeSentenceTranslator { _ in "訳" },
            explainer: FakeSentenceExplainer(isAvailable: false) { _, _ in throw FakeError() },
            fallback: unavailableFallback
        )
        #expect(analyzer.isAvailable)
        #expect(!analyzer.canExplain)
        #expect(try await analyzer.analyze("Hi.") == SentenceAnalysis(translation: "訳", explanation: ""))
    }

    @Test func throwsWhenTranslatorFailsWithoutFallback() async {
        let analyzer = TranslateThenExplainAnalyzer(
            translator: FakeSentenceTranslator { _ in throw FakeError() },
            explainer: FakeSentenceExplainer(isAvailable: false) { _, _ in "" },
            fallback: FakeSentenceAnalyzer(isAvailable: false) { _ in SentenceAnalysis(translation: "使われない", explanation: "") }
        )
        await #expect(throws: FakeError.self) { try await analyzer.analyze("Hi.") }
    }

    @Test func availableWhenEitherTranslatorOrFallbackIs() {
        func analyzer(translator: Bool, fallback: Bool) -> TranslateThenExplainAnalyzer {
            TranslateThenExplainAnalyzer(
                translator: FakeSentenceTranslator(isAvailable: translator) { _ in "訳" },
                explainer: Self.explainer,
                fallback: FakeSentenceAnalyzer(isAvailable: fallback) { _ in SentenceAnalysis(translation: "訳", explanation: "") }
            )
        }
        #expect(analyzer(translator: true, fallback: false).isAvailable)
        #expect(analyzer(translator: false, fallback: true).isAvailable)
        #expect(!analyzer(translator: false, fallback: false).isAvailable)
    }
}

struct PlamoTranslatorTests {
    @Test func promptKeepsSentenceOutOfSpecialParts() {
        #expect(PlamoTranslator.prompt(for: "Hi <|plamo:tag|> there.") == [
            .special("<|plamo:tag|>dataset<|plamo:msg|>translation<|plamo:tag|>input<|plamo:msg|>"),
            .text("Hi <|plamo:tag|> there."),
            .special("<|plamo:tag|>output<|plamo:key|>lang<|plamo:val|>ja<|plamo:msg|>"),
        ])
    }

    @Test func unavailableWithoutModel() {
        #expect(!PlamoTranslator(modelURL: nil).isAvailable)
    }
}
