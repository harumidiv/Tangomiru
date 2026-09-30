import Testing
@testable import Tangomiru

struct FoundationModelsComprehensionGeneratorTests {
    @Test func promptIncludesPassageAndCount() {
        #expect(FoundationModelsComprehensionGenerator.prompt(passage: "People took it for granted.", count: 2) == """
        # 本文
        People took it for granted.
        # 作る問題の数
        2問
        """)
    }

    @Test func buildsQuestionWithCorrectAnswerAtAnswerIndex() {
        var rng = SeededRandom(seed: 2)
        let question = FoundationModelsComprehensionGenerator.question(
            text: "トムはどうやって学校へ行きましたか？", correct: "歩いて行った",
            wrong: ["バスで行った", "自転車で行った", "車で行った"], evidence: "Tom walked.", using: &rng
        )
        #expect(question.choices[question.answerIndex] == "歩いて行った")
        #expect(question.choices.count == 4)
        #expect(question.evidence == "Tom walked.")
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsComprehensionGenerator().isAvailable
    }
}
