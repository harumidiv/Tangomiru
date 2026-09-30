import Testing
@testable import Tangomiru

struct FoundationModelsSentenceAnalyzerTests {
    @Test func promptContainsSentence() {
        #expect(FoundationModelsSentenceAnalyzer.prompt(for: "She had to leave early.") == """
        # 英文
        She had to leave early.
        """)
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsSentenceAnalyzer().isAvailable
    }
}
