import Testing
@testable import Tangomiru

struct DictionaryExtractorTests {
    let dictionary = FakeDictionary(entries: [
        "ice cream": "アイスクリーム", "ice cream soda": "クリームソーダ",
        "ice": "氷", "cream": "クリーム", "soda": "ソーダ",
        "run": "走る", "grant": "許可する", "for granted": "当然のこととして",
        "ubiquitous": "至る所にある", "tokyo": "東京", "apple": "りんご", "the": "その", "n't": "否定",
    ])

    private func extract(_ specs: [String], sentences: [String] = ["context"], basic: Set<String> = ["the"]) -> [ExtractedItem] {
        DictionaryExtractor(dictionary: dictionary, basicWords: basic).extract(from: tokenized(specs, sentences: sentences))
    }

    @Test func prefersLongestPhrase() {
        #expect(extract(["ice", "cream", "soda"]).map(\.term) == ["ice cream soda"])
    }

    @Test func phraseTokensAreNotExtractedAsWords() {
        let items = extract(["ice", "cream"])
        #expect(items.map(\.term) == ["ice cream"])
        #expect(items[0].occurrences == [TextSpan(location: 0, length: 9)])
    }

    @Test func phraseDoesNotSpanPunctuation() {
        #expect(extract(["ice", ",", "cream"]).map(\.term) == ["ice", "cream"])
    }

    @Test func phraseDoesNotSpanSentences() {
        let items = extract(["ice", ".", "cream"], sentences: ["s0", "s1"])
        #expect(items.map(\.term) == ["ice", "cream"])
        #expect(items[1].contextSentence == "s1")
    }

    @Test func matchesPhraseUsingSurfaceForm() {
        #expect(extract(["for", "granted/grant"]).map(\.term) == ["for granted"])
    }

    @Test func usesLemmaForWords() {
        let items = extract(["ran/run"])
        #expect(items.map(\.term) == ["run"])
        #expect(items[0].meaning == "走る")
        #expect(items[0].source == .dictionary)
    }

    @Test func excludesBasicProperNounsNumbersAndUnknown() {
        #expect(extract(["the", "Tokyo*", "2020", "zzzz", "ubiquitous"]).map(\.term) == ["ubiquitous"])
    }

    @Test func excludesByBasicWordLemma() {
        #expect(extract(["running/run"], basic: ["run"]).isEmpty)
    }

    @Test func mergesDuplicatesKeepingFirstContext() {
        let items = extract(["Apple/apple", ".", "apple"], sentences: ["first", "second"])
        #expect(items.count == 1)
        #expect(items[0].occurrences.count == 2)
        #expect(items[0].contextSentence == "first")
    }

    @Test func sortsByFirstOccurrence() {
        #expect(extract(["ubiquitous", ",", "ice", "cream"]).map(\.term) == ["ubiquitous", "ice cream"])
    }

    @Test func rejectsContractionFragments() {
        #expect(extract(["do", "n't"]).isEmpty)
        #expect(!DictionaryExtractor.isWordLike("'s"))
        #expect(DictionaryExtractor.isWordLike("well-known"))
    }

    @Test func phraseKeysCombineSurfaceAndLemma() {
        let keys = DictionaryExtractor.phraseKeys(for: tokenized(["took/take", "off"]).tokens)
        #expect(keys == ["took off", "take off"])
    }
}
