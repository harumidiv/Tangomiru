import Testing
@testable import Tangomiru

struct SentenceAnalysisValidatorTests {
    @Test func keepsValidAnalysis() {
        let analysis = SentenceAnalysis(translation: "彼女は早く出なければならなかった。", explanation: "had to は過去の義務を表す。")
        #expect(SentenceAnalysisValidator.validated(analysis) == analysis)
    }

    @Test func trimsWhitespace() {
        let analysis = SentenceAnalysis(translation: "  訳 \n", explanation: " 説明 ")
        #expect(SentenceAnalysisValidator.validated(analysis) == SentenceAnalysis(translation: "訳", explanation: "説明"))
    }

    @Test func rejectsEmptyTranslation() {
        #expect(SentenceAnalysisValidator.validated(SentenceAnalysis(translation: "  ", explanation: "説明")) == nil)
    }

    @Test func allowsMissingExplanation() {
        #expect(SentenceAnalysisValidator.validated(SentenceAnalysis(translation: "訳", explanation: " "))
            == SentenceAnalysis(translation: "訳", explanation: ""))
    }
}
