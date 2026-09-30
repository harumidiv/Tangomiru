import Testing
@testable import Tangomiru

struct QuizCountdownTests {
    @Test func startsFull() {
        #expect(QuizCountdown.remainingFraction(elapsed: .zero) == 1)
    }

    @Test func decreasesLinearlyOverTenSeconds() {
        #expect(QuizCountdown.remainingFraction(elapsed: .seconds(2.5)) == 0.75)
        #expect(QuizCountdown.remainingFraction(elapsed: .seconds(5)) == 0.5)
    }

    @Test func clampsAtZeroAfterLimit() {
        #expect(QuizCountdown.remainingFraction(elapsed: .seconds(10)) == 0)
        #expect(QuizCountdown.remainingFraction(elapsed: .seconds(12)) == 0)
    }

    @Test func limitIsTenSeconds() {
        #expect(QuizCountdown.limit == .seconds(10))
    }
}
