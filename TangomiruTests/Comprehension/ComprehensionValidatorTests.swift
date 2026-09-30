import Testing
@testable import Tangomiru

struct ComprehensionValidatorTests {
    static let passage = "People took it for granted. They had to give up their devices for a day."

    private func question(
        question: String = "人々は何をしなければなりませんでしたか？",
        choices: [String] = ["機器を手放す", "旅行する", "働く", "眠る"],
        answerIndex: Int = 0,
        evidence: String? = "They had to give up their devices for a day."
    ) -> ComprehensionQuestion {
        ComprehensionQuestion(question: question, choices: choices, answerIndex: answerIndex, evidence: evidence)
    }

    @Test func keepsValidQuestion() {
        #expect(ComprehensionValidator.validated(question(), passage: Self.passage) == question())
    }

    @Test(arguments: [
        ComprehensionQuestion(question: "q", choices: ["a", "b", "c"], answerIndex: 0, evidence: nil),
        ComprehensionQuestion(question: "q", choices: ["a", "b", "b", "c"], answerIndex: 0, evidence: nil),
        ComprehensionQuestion(question: "q", choices: ["a", "b", "c", "d"], answerIndex: 4, evidence: nil),
        ComprehensionQuestion(question: " ", choices: ["a", "b", "c", "d"], answerIndex: 0, evidence: nil),
    ])
    func rejectsBrokenQuestion(broken: ComprehensionQuestion) {
        #expect(ComprehensionValidator.validated(broken, passage: Self.passage) == nil)
    }

    @Test func dropsEvidenceNotInPassage() {
        let result = ComprehensionValidator.validated(question(evidence: "They went to the moon."), passage: Self.passage)
        #expect(result != nil)
        #expect(result?.evidence == nil)
    }

    @Test func matchesEvidenceIgnoringCaseAndSurroundingSpaces() {
        let result = ComprehensionValidator.validated(question(evidence: "  people took it for granted.  "), passage: Self.passage)
        #expect(result?.evidence == "people took it for granted.")
    }
}
