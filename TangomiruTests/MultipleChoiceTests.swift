import Testing
@testable import Tangomiru

struct MultipleChoiceTests {
    @Test func placesCorrectAnswerAmongWrongOnes() {
        var rng = SeededRandom(seed: 4)
        let result = MultipleChoice.shuffled(correct: "正解", wrong: ["誤1", "誤2", "誤3"], using: &rng)
        #expect(Set(result.choices) == ["正解", "誤1", "誤2", "誤3"])
        #expect(result.choices[result.answerIndex] == "正解")
    }

    @Test func correctPositionVaries() {
        var positions = Set<Int>()
        for seed in 1...20 {
            var rng = SeededRandom(seed: UInt64(seed))
            positions.insert(MultipleChoice.shuffled(correct: "正解", wrong: ["a", "b", "c"], using: &rng).answerIndex)
        }
        #expect(positions.count > 1)
    }
}
