import Testing
@testable import Tangomiru

struct SentenceSplitterTests {
    @Test func splitsIntoSentences() {
        let sentences = SentenceSplitter.sentences(in: "I like cats. Dogs are loyal!\n\nDo you agree?")
        #expect(sentences == ["I like cats.", "Dogs are loyal!", "Do you agree?"])
    }

    @Test func dropsFragmentsWithoutLetters() {
        #expect(SentenceSplitter.sentences(in: "Hello.\n\n...\n\n123.\n ") == ["Hello."])
    }

    @Test func emptyTextGivesNoSentences() {
        #expect(SentenceSplitter.sentences(in: "   ").isEmpty)
    }
}
