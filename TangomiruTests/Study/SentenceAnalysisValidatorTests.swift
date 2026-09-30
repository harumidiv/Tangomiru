import Testing
@testable import Tangomiru

struct SentenceAnalysisValidatorTests {
    static let sentence = "She had to leave early."

    private func analysis(
        translation: String = "彼女は早く出なければならなかった。",
        parts: [SentencePart] = [SentencePart(role: "主語", text: "She"), SentencePart(role: "動詞", text: "had to leave")],
        points: [GrammarPoint] = [GrammarPoint(title: "had to", explanation: "〜しなければならなかった")],
        quiz: GrammarQuiz? = GrammarQuiz(question: "had to の意味は？", choices: ["義務", "推量", "許可", "能力"], answerIndex: 0)
    ) -> SentenceAnalysis {
        SentenceAnalysis(translation: translation, parts: parts, points: points, quiz: quiz)
    }

    @Test func keepsValidAnalysis() {
        #expect(SentenceAnalysisValidator.validated(analysis(), sentence: Self.sentence) == analysis())
    }

    @Test func rejectsEmptyTranslation() {
        #expect(SentenceAnalysisValidator.validated(analysis(translation: "  "), sentence: Self.sentence) == nil)
    }

    @Test func dropsPartsNotInSentence() {
        let result = SentenceAnalysisValidator.validated(analysis(parts: [
            SentencePart(role: "主語", text: "she"),
            SentencePart(role: "目的語", text: "the book"),
            SentencePart(role: " ", text: "early"),
        ]), sentence: Self.sentence)
        #expect(result?.parts == [SentencePart(role: "主語", text: "she")])
    }

    @Test func keepsAtMostThreeNonEmptyPoints() {
        let points = [
            GrammarPoint(title: "a", explanation: "1"), GrammarPoint(title: "", explanation: "x"),
            GrammarPoint(title: "b", explanation: "2"), GrammarPoint(title: "c", explanation: "3"),
            GrammarPoint(title: "d", explanation: "4"),
        ]
        let result = SentenceAnalysisValidator.validated(analysis(points: points), sentence: Self.sentence)
        #expect(result?.points.map(\.title) == ["a", "b", "c"])
    }

    @Test(arguments: [
        GrammarQuiz(question: "q", choices: ["a", "b", "c"], answerIndex: 0),
        GrammarQuiz(question: "q", choices: ["a", "b", "c", "c"], answerIndex: 0),
        GrammarQuiz(question: "q", choices: ["a", "b", "c", "d"], answerIndex: 4),
        GrammarQuiz(question: " ", choices: ["a", "b", "c", "d"], answerIndex: 1),
    ])
    func dropsBrokenQuiz(quiz: GrammarQuiz) {
        let result = SentenceAnalysisValidator.validated(analysis(quiz: quiz), sentence: Self.sentence)
        #expect(result != nil)
        #expect(result?.quiz == nil)
    }
}
