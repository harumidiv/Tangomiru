import Testing
@testable import Tangomiru

struct FoundationModelsSentenceAnalyzerTests {
    @Test func promptContainsSentence() {
        #expect(FoundationModelsSentenceAnalyzer.prompt(for: "She had to leave early.") == """
        # 英文
        She had to leave early.
        """)
    }

    @Test func buildsQuizWithCorrectAnswerAtAnswerIndex() {
        var rng = SeededRandom(seed: 3)
        let quiz = FoundationModelsSentenceAnalyzer.quiz(
            question: "had to の意味は？", correct: "〜しなければならなかった",
            wrong: ["〜するつもりだった", "〜してもよかった", "〜できた"], using: &rng
        )
        #expect(quiz.choices[quiz.answerIndex] == "〜しなければならなかった")
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsSentenceAnalyzer().isAvailable
    }
}
