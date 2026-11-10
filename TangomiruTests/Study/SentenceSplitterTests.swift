import Foundation
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

    @Test func slicesPointToSentencesInBody() {
        let body = "  I like 🐈 cats.\n\n...\n\nDogs are loyal!  "
        let slices = SentenceSplitter.slices(in: body)
        #expect(slices.map(\.text) == ["I like 🐈 cats.", "Dogs are loyal!"])
        for slice in slices {
            let range = NSRange(location: slice.span.location, length: slice.span.length)
            #expect((body as NSString).substring(with: range) == slice.text)
        }
    }
}
