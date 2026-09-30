import Testing
@testable import Tangomiru

/// 同梱の辞書・基本語リストと実際の NLTagger を使った抽出の結合テスト（Task 16 の手動確認項目を自動化）
struct BundledExtractionTests {
    static let sample = """
    The ubiquitous smartphone has fundamentally transformed how we communicate. \
    Many people took it for granted until the outage, when they had to give up their devices for a day. \
    Researchers argue that this dependence isn't unprecedented, and John’s team agrees.
    """

    @Test func extractsAdvancedWordsAndSkipsBasicOnes() async throws {
        let pipeline = ExtractionPipeline(
            extractor: DictionaryExtractor(dictionary: try EJDictionary.loadBundled(), basicWords: try BasicWords.loadBundled()),
            enricher: nil
        )
        let result = await pipeline.run(Self.sample)
        let terms = Set(result.items.map(\.term))
        #expect(terms.isSuperset(of: ["ubiquitous", "unprecedented"]))
        #expect(terms.isDisjoint(with: ["the", "people", "day", "have", "take", "their"]))
        #expect(!terms.contains { $0.hasPrefix("'") || $0.hasPrefix("’") || $0.hasPrefix("n'") || $0.hasPrefix("n’") })
        #expect(result.items.allSatisfy { !$0.meaning.isEmpty && !$0.occurrences.isEmpty })
    }

    @Test func skipsContractionsPronounsAndInterjections() async throws {
        let pipeline = ExtractionPipeline(
            extractor: DictionaryExtractor(dictionary: try EJDictionary.loadBundled(), basicWords: try BasicWords.loadBundled()),
            enricher: nil
        )
        let text = "Oh, I won’t go. You can’t stop me. An hour ago my friend and her dog said hello. OK, see you at 5 PM, okay?"
        let terms = Set(await pipeline.run(text).items.map(\.term))
        #expect(terms.isDisjoint(with: ["wo", "ca", "oh", "an", "my", "her", "hello", "ok", "okay", "pm"]), "\(terms)")
    }

    @Test func includesBasicWordsWhenToggledButStillSkipsFunctionWords() async throws {
        let excluded = BasicWords.excludedWords(basic: try BasicWords.loadBundled(), includeBasicWords: true)
        let pipeline = ExtractionPipeline(
            extractor: DictionaryExtractor(dictionary: try EJDictionary.loadBundled(), basicWords: excluded),
            enricher: nil
        )
        let terms = Set(await pipeline.run(Self.sample).items.map(\.term))
        #expect(terms.isSuperset(of: ["person", "day", "ubiquitous"]))  // people は原形の person として拾う
        #expect(terms.isDisjoint(with: ["the", "their", "have", "had", "for", "to"]))
    }
}
