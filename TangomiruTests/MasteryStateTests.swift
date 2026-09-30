import Testing
@testable import Tangomiru

struct MasteryStateTests {
    @Test(arguments: [
        (nil, MasteryState.unseen), (-1, .veryWeak), (0, .weak), (1, .vague), (2, .mastered),
    ] as [(Int?, MasteryState)])
    func mapsScore(score: Int?, expected: MasteryState) {
        #expect(MasteryState(score: score) == expected)
    }

    @Test func labels() {
        #expect(MasteryState.allCases.map(\.label) == ["超苦手", "苦手", "未学習", "うろ覚え", "覚えた"])
    }

    @Test func priorityFollowsQuizOrder() {
        let sorted = MasteryState.allCases.sorted { $0.priority < $1.priority }
        #expect(sorted == [.veryWeak, .weak, .unseen, .vague, .mastered])
    }

    @Test func displayOrderStartsWithMastered() {
        #expect(MasteryState.displayOrder == [.mastered, .vague, .weak, .veryWeak, .unseen])
    }
}
