import Testing
@testable import Tangomiru

struct SentenceStudyModelTests {
    static let sentences = ["First one.", "Second one.", "Third one."]

    private static func analysis(for sentence: String) -> SentenceAnalysis {
        SentenceAnalysis(translation: "\(sentence)の訳", explanation: "\(sentence)の説明")
    }

    private func model(recorder: CallRecorder = CallRecorder()) -> SentenceStudyModel {
        SentenceStudyModel(sentences: Self.sentences, analyzer: FakeSentenceAnalyzer { sentence in
            recorder.record([sentence])
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

    @Test func revealShowsExplanation() async {
        let model = model()
        model.start()
        model.reveal()
        #expect(model.isRevealed)
    }

    @Test func nextMovesOnResetsRevealAndPrefetches() async {
        let recorder = CallRecorder()
        let model = model(recorder: recorder)
        model.start()
        await settle(model)
        model.reveal()
        model.next()
        await settle(model)
        #expect(model.index == 1)
        #expect(!model.isRevealed)
        #expect(recorder.calls.flatMap { $0 }.filter { $0 == "Second one." }.count == 1)
        #expect(recorder.calls.flatMap { $0 }.contains("Third one."))
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
            SentenceAnalysis(translation: "", explanation: "説明")
        })
        model.start()
        await settle(model)
        #expect(model.currentState == .failed)
    }

    @Test func usesSavedAnalysisWithoutGenerating() async {
        let recorder = CallRecorder()
        let saved = Self.analysis(for: "保存済み")
        let model = SentenceStudyModel(
            sentences: Self.sentences, saved: ["First one.": saved],
            analyzer: FakeSentenceAnalyzer { sentence in
                recorder.record([sentence])
                return Self.analysis(for: sentence)
            }
        )
        model.start()
        await settle(model)
        #expect(model.currentAnalysis == saved)
        #expect(recorder.calls.flatMap { $0 } == ["Second one."])
    }

    @Test func reportsNewlyGeneratedAnalysesForSaving() async {
        let reported = CallRecorder()
        let model = SentenceStudyModel(
            sentences: Self.sentences, saved: ["First one.": Self.analysis(for: "x")],
            analyzer: FakeSentenceAnalyzer { Self.analysis(for: $0) },
            onAnalyzed: { sentence, analysis in reported.record([sentence, analysis.translation]) }
        )
        model.start()
        await settle(model)
        #expect(reported.calls == [["Second one.", "Second one.の訳"]])
    }
}
