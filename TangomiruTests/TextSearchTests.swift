import Testing
@testable import Tangomiru

struct TextSearchTests {
    @Test func findsAllCaseInsensitiveMatches() {
        #expect(TextSearch.occurrences(of: "give up", in: "Give up? Never give up.") == [
            TextSpan(location: 0, length: 7), TextSpan(location: 15, length: 7),
        ])
    }

    @Test func respectsWordBoundaries() {
        #expect(TextSearch.occurrences(of: "give up", in: "forgive upstairs").isEmpty)
    }

    @Test func usesUTF16OffsetsAfterEmoji() {
        #expect(TextSearch.occurrences(of: "give up", in: "😀 give up") == [TextSpan(location: 3, length: 7)])
    }

    @Test func emptyTermFindsNothing() {
        #expect(TextSearch.occurrences(of: "", in: "abc").isEmpty)
    }
}
