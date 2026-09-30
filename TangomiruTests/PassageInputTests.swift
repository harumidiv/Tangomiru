import Testing
@testable import Tangomiru

struct PassageInputTests {
    @Test func validatesBody() {
        #expect(PassageInput.validate("  \n ") == .empty)
        #expect(PassageInput.validate(String(repeating: "a", count: 10_001)) == .tooLong)
        #expect(PassageInput.validate(String(repeating: "a", count: 10_000)) == nil)
    }

    @Test func usesGivenTitle() {
        #expect(PassageInput.title("  My title ", body: "Body") == "My title")
    }

    @Test func generatesTitleFromFirstLine() {
        #expect(PassageInput.title("", body: "\n  Short line.\nNext") == "Short line.")
        let long = String(repeating: "abcde ", count: 10)
        #expect(PassageInput.title(" ", body: long) == String(long.prefix(30)) + "…")
    }
}
