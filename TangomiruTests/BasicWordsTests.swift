import Testing
@testable import Tangomiru

struct BasicWordsTests {
    @Test func parseTrimsAndLowercases() {
        #expect(BasicWords.parse(" The\nI\n\nrun \n") == ["the", "i", "run"])
    }

    @Test func loadsBundledList() throws {
        let words = try BasicWords.loadBundled()
        #expect(words.count > 1_900)
        #expect(words.contains("the"))
        #expect(words.contains("run"))
        #expect(!words.contains("ubiquitous"))
        #expect(words.isSuperset(of: ["their", "themselves", "whose"]))
    }

    @Test func functionWordsCoverCoreGrammarWords() {
        #expect(BasicWords.functionWords.isSuperset(of: [
            "the", "a", "and", "of", "be", "have", "do", "i", "you", "it", "to", "in", "can", "will", "not", "their",
        ]))
        #expect(!BasicWords.functionWords.contains("people"))
    }

    @Test func excludedWordsDependOnToggle() {
        let basic: Set<String> = ["people", "day", "the"]
        #expect(BasicWords.excludedWords(basic: basic, includeBasicWords: false) == basic)
        #expect(BasicWords.excludedWords(basic: basic, includeBasicWords: true) == BasicWords.functionWords)
    }
}
