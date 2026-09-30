import Testing
@testable import Tangomiru

struct ComprehensionBuilderTests {
    static let passage = (1...7).map { "Sentence number \($0) is here." }.joined(separator: " ")

    private static func question(_ tag: String) -> ComprehensionQuestion {
        ComprehensionQuestion(question: tag, choices: ["正", "誤1", "誤2", "誤3"], answerIndex: 0, evidence: nil)
    }

    @Test func buildsGistThenDetails() async {
        let generator = FakeComprehensionGenerator(
            gist: { _ in Self.question("gist") },
            handler: { _, count in (0..<count).map { Self.question("d\($0)") } }
        )
        let questions = await ComprehensionBuilder(passage: Self.passage).buildAll(using: generator)
        #expect(questions.map(\.question) == ["gist", "d0", "d1", "d2"])
    }

    @Test func fillsWithDetailsWhenGistFails() async {
        let generator = FakeComprehensionGenerator { _, count in (0..<count).map { Self.question("d\($0)") } }
        let questions = await ComprehensionBuilder(passage: Self.passage).buildAll(using: generator)
        #expect(questions.count == 4)
    }

    @Test func dropsInvalidGist() async {
        let generator = FakeComprehensionGenerator(
            gist: { _ in ComprehensionQuestion(question: "gist", choices: ["a"], answerIndex: 0, evidence: nil) },
            handler: { _, count in (0..<count).map { Self.question("d\($0)") } }
        )
        let questions = await ComprehensionBuilder(passage: Self.passage).buildAll(using: generator)
        #expect(!questions.map(\.question).contains("gist"))
        #expect(questions.count == 4)
    }
}
