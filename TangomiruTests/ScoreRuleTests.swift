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
}
