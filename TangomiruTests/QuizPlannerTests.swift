import Testing
@testable import Tangomiru

struct QuizPlannerTests {
    @Test func ordersByPriority() {
        let cards = [
            makeCard("m", score: 2), makeCard("v", score: 1), makeCard("u", score: nil),
            makeCard("w", score: 0), makeCard("vw", score: -1),
        ]
        var rng = SeededRandom(seed: 1)
        let selected = QuizPlanner.select(from: cards, length: .all, using: &rng)
        #expect(selected.map(\.term) == ["vw", "w", "u", "v", "m"])
    }

    @Test(arguments: [(QuizLength.ten, 10), (.twenty, 20), (.all, 25)] as [(QuizLength, Int)])
    func limitsCount(length: QuizLength, expected: Int) {
        let cards = (0..<25).map { makeCard("t\($0)", score: nil) }
        var rng = SeededRandom(seed: 1)
        #expect(QuizPlanner.select(from: cards, length: length, using: &rng).count == expected)
    }

    @Test func returnsAllWhenFewerThanLimit() {
        let cards = (0..<3).map { makeCard("t\($0)", score: nil) }
        var rng = SeededRandom(seed: 1)
        #expect(QuizPlanner.select(from: cards, length: .ten, using: &rng).count == 3)
    }

    @Test func limitPrefersWeakerCards() {
        let mastered = (0..<10).map { makeCard("m\($0)", score: 2) }
        let weak = (0..<5).map { makeCard("w\($0)", score: 0) }
        var rng = SeededRandom(seed: 1)
        let selected = QuizPlanner.select(from: mastered + weak, length: .ten, using: &rng)
        #expect(Set(weak.map(\.id)).isSubset(of: Set(selected.map(\.id))))
    }

    @Test func shufflesWithinSameState() {
        let cards = (0..<10).map { makeCard("t\($0)", score: nil) }
        var rng1 = SeededRandom(seed: 1)
        var rng2 = SeededRandom(seed: 2)
        let a = QuizPlanner.select(from: cards, length: .all, using: &rng1).map(\.term)
        let b = QuizPlanner.select(from: cards, length: .all, using: &rng2).map(\.term)
        #expect(a != b)
        #expect(Set(a) == Set(b))
    }

    @Test func emptyInputReturnsEmpty() {
        var rng = SeededRandom(seed: 1)
        #expect(QuizPlanner.select(from: [], length: .ten, using: &rng).isEmpty)
    }

    @Test func lengthLabels() {
        #expect(QuizLength.allCases.map(\.label) == ["10問", "20問", "全問"])
        #expect(QuizLength.all.limit == nil)
        #expect(QuizLength.twenty.limit == 20)
    }
}
