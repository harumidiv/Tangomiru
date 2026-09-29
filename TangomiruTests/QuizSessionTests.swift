import Foundation
import Testing
@testable import Tangomiru

struct QuizSessionTests {
    private func session(_ cards: [QuizCard], length: QuizLength = .all) -> QuizSession {
        QuizSession(cards: cards, length: length, fallbackMeanings: ["空", "海", "山"], rng: SeededRandom(seed: 7))
    }

    @Test func correctFirstAnswerRaisesScore() {
        let card = makeCard("a", score: nil)
        var s = session([card])
        let feedback = s.answer("aの意味")
        #expect(feedback == AnswerFeedback(isCorrect: true, correctAnswer: "aの意味"))
        #expect(s.changes == [ScoreChange(cardID: card.id, term: "a", before: nil, after: 1)])
        s.advance()
        #expect(s.isFinished)
        #expect(s.correctCount == 1)
    }

    @Test func wrongAnswerSchedulesRetryThreeQuestionsLater() {
        let cards = (0..<6).map { makeCard("t\($0)", score: 1) }
        var s = session(cards)
        let first = s.current!.card
        s.answer("wrong")
        s.advance()
        var seen: [QuizQuestion] = []
        while let question = s.current {
            seen.append(question)
            s.answer(question.card.meaning)
            s.advance()
        }
        #expect(seen.count == 6)
        #expect(seen[3].card.id == first.id)
        #expect(seen[3].isRetry)
        #expect(s.totalCount == 7)
    }

    @Test func retryDoesNotChangeScore() {
        var s = session([makeCard("a", score: 2)])
        s.answer("wrong")
        s.advance()
        #expect(s.current?.isRetry == true)
        s.answer("aの意味")
        s.advance()
        #expect(s.isFinished)
        #expect(s.changes.map(\.after) == [1])
        #expect(s.correctCount == 0)
    }

    @Test func retryNearEndIsAppended() {
        var s = session([makeCard("a", score: nil), makeCard("b", score: nil)])
        let firstTerm = s.current!.card.term
        s.answer("\(firstTerm)の意味")
        s.advance()
        s.answer("wrong")
        s.advance()
        #expect(s.current?.isRetry == true)
        #expect(s.totalCount == 3)
    }

    @Test func answeringTwiceCountsOnce() {
        var s = session([makeCard("a", score: nil)])
        s.answer("aの意味")
        let second = s.answer("wrong")
        #expect(second.isCorrect)
        #expect(s.changes.count == 1)
        #expect(s.changes[0].after == 1)
        s.advance()
        #expect(s.isFinished)
    }

    @Test func emptyCardsFinishImmediately() {
        let s = session([])
        #expect(s.isFinished)
        #expect(s.questionCount == 0)
    }

    @Test func respectsLength() {
        let s = session((0..<25).map { makeCard("t\($0)", score: nil) }, length: .ten)
        #expect(s.questionCount == 10)
        #expect(s.totalCount == 10)
    }

    @Test func choicesIncludeCorrectAnswer() {
        let s = session((0..<4).map { makeCard("t\($0)", score: nil) })
        let question = s.current!
        #expect(question.choices.count == 4)
        #expect(question.choices.contains(question.card.meaning))
    }

    @Test(arguments: [
        (nil, 1, true, false), (nil, 0, false, true), (2, 1, false, true),
        (0, 1, true, false), (-1, -1, false, false), (2, 2, false, false),
    ] as [(Int?, Int, Bool, Bool)])
    func changeDirection(before: Int?, after: Int, promotion: Bool, demotion: Bool) {
        let change = ScoreChange(cardID: UUID(), term: "x", before: before, after: after)
        #expect(change.isPromotion == promotion)
        #expect(change.isDemotion == demotion)
    }
}
