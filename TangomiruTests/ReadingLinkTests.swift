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
}
