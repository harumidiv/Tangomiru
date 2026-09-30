import Testing
@testable import Tangomiru

struct MasteryStatsTests {
    @Test func countsEachState() {
        let stats = MasteryStats(scores: [nil, -1, 0, 1, 2, 2])
        #expect(stats.total == 6)
        #expect(stats.count(.mastered) == 2)
        #expect(stats.count(.veryWeak) == 1)
        #expect(stats.count(.unseen) == 1)
        #expect(abs(stats.masteredRate - 2.0 / 6.0) < 0.0001)
        #expect(stats.percentText == "33%")
    }

    @Test func emptyIsZero() {
        let stats = MasteryStats(scores: [])
        #expect(stats.masteredRate == 0)
        #expect(stats.percentText == "0%")
    }
}
