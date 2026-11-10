import Foundation
import Testing
@testable import Tangomiru

struct ReadingLinkTests {
    @Test func roundTripsItemID() {
        let id = UUID()
        #expect(ReadingLink.itemID(from: ReadingLink.url(for: id)) == id)
    }

    @Test func rejectsOtherURLs() {
        #expect(ReadingLink.itemID(from: URL(string: "https://example.com/item/x")!) == nil)
    }

    @Test func roundTripsWord() {
        for word in ["rooftops", "don't", "café", "a&b=c?"] {
            #expect(ReadingLink.word(from: ReadingLink.url(forWord: word)) == word)
        }
    }

    @Test func itemAndWordLinksDoNotMix() {
        #expect(ReadingLink.word(from: ReadingLink.url(for: UUID())) == nil)
        #expect(ReadingLink.itemID(from: ReadingLink.url(forWord: "cats")) == nil)
    }
}
