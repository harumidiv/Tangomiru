import Testing
@testable import Tangomiru

struct ScoreRuleTests {
    @Test(arguments: [
        (nil, true, 1), (nil, false, 0),
        (-1, true, 0), (-1, false, -1),
        (0, true, 1), (0, false, -1),
        (1, true, 2), (1, false, 0),
        (2, true, 2), (2, false, 1),
    ] as [(Int?, Bool, Int)])
    func apply(score: Int?, correct: Bool, expected: Int) {
        #expect(ScoreRule.apply(score: score, correct: correct) == expected)
    }

    @Test(arguments: [
        (nil, 1, 2), (nil, 2, 2), (nil, 3, 1),
        (0, 1, 1), (1, 2, 2),
        (nil, 8, 0), (2, 8, 1), (1, 9, 0), (0, 10, -1), (-1, 8, -1),
        (1, 5, 2),
    ] as [(Int?, Int, Int)])
    func applyWithElapsed(score: Int?, seconds: Int, expected: Int) {
        #expect(ScoreRule.apply(score: score, correct: true, elapsed: .seconds(seconds)) == expected)
    }

    @Test func wrongAnswerIgnoresElapsed() {
        #expect(ScoreRule.apply(score: nil, correct: false, elapsed: .seconds(1)) == 0)
        #expect(ScoreRule.apply(score: 2, correct: false, elapsed: .seconds(9)) == 1)
    }
}
