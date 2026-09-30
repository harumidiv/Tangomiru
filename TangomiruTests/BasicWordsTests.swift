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
}
