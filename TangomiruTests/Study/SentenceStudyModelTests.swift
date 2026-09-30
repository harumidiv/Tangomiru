import Testing
@testable import Tangomiru

struct SentenceStudyModelTests {
    static let sentences = ["First one.", "Second one.", "Third one."]

    private static func analysis(for sentence: String) -> SentenceAnalysis {
        SentenceAnalysis(
            translation: "\(sentence)の訳", parts: [], points: [],
            quiz: GrammarQuiz(question: "q", choices: ["a", "b", "c", "d"], answerIndex: 2)
        )
    }

    private func model(fail: Set<String> = [], recorder: CallRecorder = CallRecorder()) -> SentenceStudyModel {
        SentenceStudyModel(sentences: Self.sentences, analyzer: FakeSentenceAnalyzer { sentence in
            recorder.record([sentence])
            if fail.contains(sentence) { throw FakeError() }
            return Self.analysis(for: sentence)
        })
    }

    private func settle(_ model: SentenceStudyModel) async {
        for index in Self.sentences.indices { await model.pendingTask(at: index)?.value }
    }

    @Test func startLoadsCurrentAndPrefetchesNext() async {
        let recorder = CallRecorder()
        let model = model(recorder: recorder)
        model.start()
        await settle(model)
        #expect(Set(recorder.calls.flatMap { $0 }) == ["First one.", "Second one."])
        #expect(model.currentSentence == "First one.")
        #expect(model.currentAnalysis?.translation == "First one.の訳")
        #expect(!model.isRevealed)
    }

    @Test func nextMovesOnResetsStateAndPrefetches() async {
        let recorder = CallRecorder()
        let model = model(recorder: recorder)
        model.start()
        await settle(model)
        model.reveal()
        model.answerQuiz(1)
        model.next()
        await settle(model)
        #expect(model.index == 1)
        #expect(!model.isRevealed)
        #expect(model.selectedQuizIndex == nil)
        #expect(recorder.calls.flatMap { $0 }.filter { $0 == "Second one." }.count == 1)
        #expect(recorder.calls.flatMap { $0 }.contains("Third one."))
    }

    @Test func answeringQuizTwiceKeepsFirstAnswer() async {
        let model = model()
        model.start()
        await settle(model)
        model.answerQuiz(2)
        model.answerQuiz(0)
        #expect(model.selectedQuizIndex == 2)
        #expect(model.isQuizCorrect == true)
    }

    @Test func answeringQuizRevealsExplanation() async {
        let model = model()
        model.start()
        await settle(model)
        #expect(!model.isRevealed)
        model.answerQuiz(1)
        #expect(model.isRevealed)
        #expect(model.isQuizCorrect == false)
    }

    @Test func failureCanBeRetried() async {
        let recorder = CallRecorder()
        let model = SentenceStudyModel(sentences: Self.sentences, analyzer: FakeSentenceAnalyzer { sentence in
            recorder.record([sentence])
            // 1文目の最初の1回だけ失敗させる
            if sentence == "First one." && recorder.calls.filter({ $0 == [sentence] }).count == 1 { throw FakeError() }
            return Self.analysis(for: sentence)
        })
        model.start()
        await settle(model)
        #expect(model.currentState == .failed)
        model.retry()
        await settle(model)
        #expect(model.currentAnalysis?.translation == "First one.の訳")
    }

    @Test func finishesAfterLastSentence() async {
        let model = model()
        model.start()
        for _ in Self.sentences { model.next() }
        #expect(model.isFinished)
        #expect(model.currentSentence == nil)
    }

    @Test func invalidOutputCountsAsFailure() async {
        let model = SentenceStudyModel(sentences: Self.sentences, analyzer: FakeSentenceAnalyzer { _ in
            SentenceAnalysis(translation: "", parts: [], points: [], quiz: nil)
        })
        model.start()
        await settle(model)
        #expect(model.currentState == .failed)
    }
}
