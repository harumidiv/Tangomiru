import Foundation
import Testing
@testable import Tangomiru

struct QuizSessionTests {
    private func session(_ cards: [QuizCard], length: QuizLength = .all) -> QuizSession {
        QuizSession(cards: cards, length: length, fallbackMeanings: ["空", "海", "山"], rng: SeededRandom(seed: 7))
    }

    /// 出題順に全問解く。wrongTerms に含まれる語だけ間違える
    private func answerAll(_ s: inout QuizSession, wrong wrongTerms: Set<String> = []) -> [QuizQuestion] {
        var seen: [QuizQuestion] = []
        while let question = s.current {
            seen.append(question)
            s.answer(wrongTerms.contains(question.card.term) ? "wrong" : question.card.meaning)
            s.advance()
        }
        return seen
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

    @Test func wrongAnswersDoNotAddQuestions() {
        var s = session((0..<6).map { makeCard("t\($0)", score: 1) })
        let seen = answerAll(&s, wrong: ["t0", "t3"])
        #expect(seen.count == 6)
        #expect(s.totalCount == 6)
        #expect(Set(seen.map(\.card.id)).count == 6)
    }

    @Test func wrongCardsListsMissedCardsInOrder() {
        var s = session((0..<5).map { makeCard("t\($0)", score: nil) })
        let seen = answerAll(&s, wrong: ["t1", "t4"])
        let expected = seen.map(\.card).filter { ["t1", "t4"].contains($0.term) }
        #expect(s.wrongCards == expected)
        #expect(s.correctCount == 3)
    }

    @Test func reviewSessionAsksMissedCardsWithoutChangingScores() {
        let cards = (0..<5).map { makeCard("t\($0)", score: 1) }
        var first = session(cards)
        _ = answerAll(&first, wrong: ["t2"])
        var review = QuizSession(
            reviewing: first.wrongCards, passageMeanings: cards.map(\.meaning),
            fallbackMeanings: [], rng: SeededRandom(seed: 1)
        )
        #expect(review.isReview)
        #expect(review.questionCount == 1)
        #expect(review.current?.choices.count == 4)
        review.answer("wrong")
        review.advance()
        #expect(review.isFinished)
        #expect(review.changes.isEmpty)
        #expect(review.wrongCards.map(\.term) == ["t2"])
    }

    @Test func answeringTwiceCountsOnce() {
        var s = session([makeCard("a", score: nil)])
        s.answer("aの意味")
        let second = s.answer("wrong")
        #expect(second.isCorrect)
        #expect(s.changes.count == 1)
        #expect(s.changes[0].after == 1)
        #expect(s.wrongCards.isEmpty)
        s.advance()
        #expect(s.isFinished)
    }

    @Test func skipCountsAsWrongAnswer() {
        let cards = (0..<5).map { makeCard("t\($0)", score: 1) }
        var s = session(cards)
        let first = s.current!.card
        let feedback = s.skip()
        #expect(feedback == AnswerFeedback(isCorrect: false, correctAnswer: first.meaning))
        #expect(s.changes == [ScoreChange(cardID: first.id, term: first.term, before: 1, after: 0)])
        #expect(s.wrongCards == [first])
        #expect(s.totalCount == 5)
    }

    @Test func skipAfterAnswerIsIgnored() {
        var s = session([makeCard("a", score: nil)])
        s.answer("aの意味")
        let feedback = s.skip()
        #expect(feedback.isCorrect)
        #expect(s.changes.map(\.after) == [1])
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
