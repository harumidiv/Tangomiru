import Testing
@testable import Tangomiru

struct EJDictionaryTests {
    let dictionary = EJDictionary(tsv: """
    run\t『走る』,駆ける / 〈人が〉(…に)『急ぐ』,突進する《+『for』(『to』)+『名』》 / 〈C〉『走ること』,駆け足
    A,a,an\t答え / アンペア
    analyse,analyze\t=analyze / 〈状況など〉を『分析する』,詳細に検討する
    'em\t=them
    them\t『彼らを』
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
        #expect(dictionary.meaning(for: "an") == "答え")
        #expect(dictionary.meaning(for: "a") == "答え")
    }

    @Test func prefersLowercaseHeadword() {
        #expect(dictionary.meaning(for: "polish") == "磨く")
    }

    @Test func ignoresHeadwordsWithoutLowercaseForm() {
        #expect(dictionary.meaning(for: "ok") == nil)
    }

    @Test func skipsCrossReferenceToFindJapaneseMeaning() {
        #expect(dictionary.meaning(for: "analyze") == "分析する")
        #expect(dictionary.meaning(for: "analyse") == "分析する")
    }

    @Test func followsReferenceWhenNoOtherMeaning() {
        #expect(dictionary.meaning(for: "'em") == "彼らを")
    }

    @Test func supportsPhrases() {
        #expect(dictionary.meaning(for: "ice cream") == "アイスクリーム")
    }

    @Test func ignoresMalformedLinesAndUnknownWords() {
        #expect(dictionary.count == 9)
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
        #expect(bundled.meaning(for: "analyze", partOfSpeech: .verb) == "分析する")
        #expect(bundled.meaning(for: "colour").map(MeaningFormatter.containsJapanese) == true)
    }
}
