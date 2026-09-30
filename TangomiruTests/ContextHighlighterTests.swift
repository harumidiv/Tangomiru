import Foundation
import Testing
@testable import Tangomiru

struct ContextHighlighterTests {
    @Test func emphasizesFirstMatch() {
        let attributed = ContextHighlighter.attributed(sentence: "She was running fast.", highlight: "running")
        #expect(String(attributed.characters) == "She was running fast.")
        let emphasized = attributed.runs
            .filter { $0.inlinePresentationIntent == .stronglyEmphasized }
            .map { String(attributed[$0.range].characters) }
        #expect(emphasized == ["running"])
    }

    @Test func leavesSentenceUnchangedWhenNotFound() {
        let attributed = ContextHighlighter.attributed(sentence: "Nothing here.", highlight: "run")
        #expect(attributed.runs.allSatisfy { $0.inlinePresentationIntent == nil })
    }
}
