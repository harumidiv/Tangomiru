import Testing
@testable import Tangomiru

struct QuizScopeTests {
    let cards = [
        makeCard("u", score: nil), makeCard("vw", score: -1), makeCard("w", score: 0),
        makeCard("v", score: 1), makeCard("m", score: 2), makeCard("u2", score: nil),
    ]

    @Test func autoKeepsAllCards() {
        #expect(QuizScope.auto.cards(from: cards).count == 6)
    }

    @Test(arguments: [
        (QuizScope.unseen, ["u", "u2"]), (.veryWeak, ["vw"]), (.weak, ["w"]), (.vague, ["v"]), (.mastered, ["m"]),
    ] as [(QuizScope, [String])])
    func filtersByState(scope: QuizScope, expected: [String]) {
        #expect(scope.cards(from: cards).map(\.term) == expected)
    }

    @Test func orderAndLabelsFollowDesign() {
        #expect(QuizScope.allCases.map(\.label) == ["おまかせ", "未学習", "超苦手", "苦手", "うろ覚え", "覚えた"])
    }

    @Test func rawValueRoundTrips() {
        for scope in QuizScope.allCases {
            #expect(QuizScope(rawValue: scope.rawValue) == scope)
        }
    }

    @Test func countsPerScope() {
        let stats = MasteryStats(scores: cards.map(\.score))
        #expect(QuizScope.auto.count(in: stats) == 6)
        #expect(QuizScope.unseen.count(in: stats) == 2)
        #expect(QuizScope.mastered.count(in: stats) == 1)
    }
}
