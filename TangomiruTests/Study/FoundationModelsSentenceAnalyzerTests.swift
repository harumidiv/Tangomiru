import Testing
@testable import Tangomiru

struct FoundationModelsSentenceAnalyzerTests {
    @Test func promptContainsSentence() {
        #expect(FoundationModelsSentenceAnalyzer.prompt(for: "She had to leave early.") == """
        # 英文
        She had to leave early.
        """)
    }

    @Test func explanationPromptContainsSentenceAndTranslation() {
        #expect(FoundationModelsSentenceAnalyzer.explanationPrompt(
            for: "She had to leave early.",
            translation: "彼女は早く帰らなければならなかった。"
        ) == """
        # 英文
        She had to leave early.

        # 日本語訳
        彼女は早く帰らなければならなかった。
        """)
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsSentenceAnalyzer().isAvailable
    }
}
