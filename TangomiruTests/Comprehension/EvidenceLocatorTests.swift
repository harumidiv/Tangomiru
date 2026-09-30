import Testing
@testable import Tangomiru

struct EvidenceLocatorTests {
    static let sentences = ["People took it for granted.", "They had to give up their devices for a day.", "Some felt relieved."]

    @Test func findsSentenceContainingEvidence() {
        #expect(EvidenceLocator.sentenceIndex(of: "They had to give up their devices for a day.", in: Self.sentences) == 1)
    }

    @Test func matchesPartialEvidenceIgnoringCase() {
        #expect(EvidenceLocator.sentenceIndex(of: "some felt relieved", in: Self.sentences) == 2)
    }

    @Test func matchesEvidenceSpanningSentencesByFirstSentence() {
        #expect(EvidenceLocator.sentenceIndex(of: "People took it for granted. They had to give up", in: Self.sentences) == 0)
    }

    @Test func returnsNilWhenNotFound() {
        #expect(EvidenceLocator.sentenceIndex(of: "Nothing like this.", in: Self.sentences) == nil)
        #expect(EvidenceLocator.sentenceIndex(of: nil, in: Self.sentences) == nil)
    }
}
