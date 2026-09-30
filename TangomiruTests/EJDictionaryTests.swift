import Testing
@testable import Tangomiru

struct EJDictionaryTests {
    let dictionary = EJDictionary(tsv: """
    run\t『走る』,駆ける / 〈人が〉(…に)『急ぐ』,突進する《+『for』(『to』)+『名』》 / 〈C〉『走ること』,駆け足
    A,a,an\tanswer / ampere
    Polish\tポーランドの
    polish\t…を磨く
    ice cream\tアイスクリーム
    OK\tOklahoma(オクラホマ州)の略
    broken line without tab
    """)

    @Test func formatsMeaning() {
        #expect(dictionary.meaning(for: "run") == "走る")
        #expect(dictionary.meaning(for: "run", partOfSpeech: .noun) == "走ること")
    }

    @Test func splitsCommaSeparatedHeadwords() {
        #expect(dictionary.meaning(for: "an") == "answer")
        #expect(dictionary.meaning(for: "a") == "answer")
    }

    @Test func prefersLowercaseHeadword() {
        #expect(dictionary.meaning(for: "polish") == "磨く")
    }

    @Test func ignoresHeadwordsWithoutLowercaseForm() {
        #expect(dictionary.meaning(for: "ok") == nil)
    }

    @Test func supportsPhrases() {
        #expect(dictionary.meaning(for: "ice cream") == "アイスクリーム")
    }

    @Test func ignoresMalformedLinesAndUnknownWords() {
        #expect(dictionary.count == 5)
        #expect(dictionary.meaning(for: "zzz") == nil)
    }

    @Test func randomMeaningsAreSingleWordsAndUnique() {
        var rng = SeededRandom(seed: 3)
        let meanings = dictionary.randomMeanings(count: 3, using: &rng)
        #expect(!meanings.isEmpty)
        #expect(!meanings.contains("アイスクリーム"))
        #expect(Set(meanings).count == meanings.count)
    }

    @Test func loadsBundledDictionary() throws {
        let bundled = try EJDictionary.loadBundled()
        #expect(bundled.count > 40_000)
        #expect(bundled.meaning(for: "ubiquitous") != nil)
    }
}
