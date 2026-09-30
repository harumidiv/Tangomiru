import Testing
@testable import Tangomiru

struct SeededRandomTests {
    @Test func sameSeedGivesSameSequence() {
        var a = SeededRandom(seed: 42)
        var b = SeededRandom(seed: 42)
        #expect((0..<5).map { _ in a.next() } == (0..<5).map { _ in b.next() })
    }

    @Test func differentSeedsDiffer() {
        var a = SeededRandom(seed: 1)
        var b = SeededRandom(seed: 2)
        #expect(a.next() != b.next())
    }
}
