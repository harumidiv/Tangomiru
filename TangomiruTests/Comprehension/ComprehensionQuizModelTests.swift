import Testing
@testable import Tangomiru

struct ComprehensionQuizModelTests {
    /// 7文 → 4問。maxChunkLength を小さくして2チャンクに分ける
    static let passage = (1...7).map { "Sentence number \($0) is here." }.joined(separator: " ")

    private static func questions(count: Int, tag: String) -> [ComprehensionQuestion] {
        (0..<count).map {
            ComprehensionQuestion(question: "\(tag)-\($0)", choices: ["正", "誤1", "誤2", "誤3"], answerIndex: 0, evidence: nil)
        }
    }

    private func model(recorder: CallRecorder = CallRecorder(), fail: @escaping @Sendable (Int) -> Bool = { _ in false }) -> ComprehensionQuizModel {
        ComprehensionQuizModel(passage: Self.passage, maxChunkLength: 120, generator: FakeComprehensionGenerator { chunk, count in
            recorder.record([chunk])
            let call = recorder.calls.count
            if fail(call) { throw FakeError() }
            return Self.questions(count: count, tag: "c\(call)")
        })
    }

    @Test func generatesPlannedNumberOfQuestionsAcrossChunks() async {
        let recorder = CallRecorder()
        let model = model(recorder: recorder)
        model.start()
        await model.generationTask?.value
        #expect(model.plannedCount == 4)
        #expect(recorder.calls.count == 2)
        #expect(model.questions.count == 4)
        #expect(!model.isGenerating)
    }

    @Test func answeringAndAdvancingTracksScore() async {
        let model = model()
        model.start()
        await model.generationTask?.value
        model.answer(0)
        model.answer(2)
        #expect(model.selectedIndex == 0)
        #expect(model.isCurrentCorrect == true)
        model.next()
        model.answer(1)
        #expect(model.isCurrentCorrect == false)
        model.next()
        model.answer(0)
        model.next()
        model.answer(0)
        model.next()
        #expect(model.isFinished)
        #expect(model.correctCount == 3)
        #expect(model.wrongQuestions.map(\.question) == ["c1-1"])
    }

    @Test func nextRequiresAnswer() async {
        let model = model()
        model.start()
        await model.generationTask?.value
        model.next()
        #expect(model.index == 0)
    }

    @Test func failedChunkIsSkipped() async {
        let model = model(fail: { $0 == 1 })
        model.start()
        await model.generationTask?.value
        #expect(model.questions.map(\.question).allSatisfy { $0.hasPrefix("c2") })
        #expect(!model.hasFailed)
    }

    @Test func allChunksFailingCanBeRetried() async {
        let recorder = CallRecorder()
        let model = model(recorder: recorder, fail: { $0 <= 2 })
        model.start()
        await model.generationTask?.value
        #expect(model.hasFailed)
        model.retry()
        await model.generationTask?.value
        #expect(!model.hasFailed)
        #expect(model.questions.count == 4)
    }

    @Test func invalidQuestionsAreDropped() async {
        let model = ComprehensionQuizModel(passage: Self.passage, maxChunkLength: 1_000, generator: FakeComprehensionGenerator { _, _ in
            [ComprehensionQuestion(question: "q", choices: ["a"], answerIndex: 0, evidence: nil)]
        })
        model.start()
        await model.generationTask?.value
        #expect(model.questions.isEmpty)
        #expect(model.hasFailed)
    }
}
