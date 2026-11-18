import Testing
@testable import Tangomiru

struct SentenceAnalysisValidatorTests {
    @Test func keepsValidAnalysis() {
        let analysis = SentenceAnalysis(translation: "彼女は早く出なければならなかった。", explanation: "had to は過去の義務を表す。")
        #expect(SentenceAnalysisValidator.validated(analysis) == analysis)
    }

    @Test func trimsWhitespace() {
        let analysis = SentenceAnalysis(translation: "  訳 \n", explanation: " 主語が省略されています。 ")
        #expect(SentenceAnalysisValidator.validated(analysis) == SentenceAnalysis(translation: "訳", explanation: "主語が省略されています。"))
    }

    @Test func rejectsEmptyTranslation() {
        #expect(SentenceAnalysisValidator.validated(SentenceAnalysis(translation: "  ", explanation: "説明")) == nil)
    }

    @Test func allowsMissingExplanation() {
        #expect(SentenceAnalysisValidator.validated(SentenceAnalysis(translation: "訳", explanation: " "))
            == SentenceAnalysis(translation: "訳", explanation: ""))
    }

    @Test func removesEnglishExplanationAndKeepsTranslation() {
        let analysis = SentenceAnalysis(translation: "早く出た。", explanation: "The verb 'left' is the simple past of 'leave'.")
        #expect(SentenceAnalysisValidator.validated(analysis)
            == SentenceAnalysis(translation: "早く出た。", explanation: "", isExplanationFailed: true))
    }

    @Test func flagsBlankExplanationWhenExpected() {
        let analysis = SentenceAnalysis(translation: "訳", explanation: " ")
        #expect(SentenceAnalysisValidator.validated(analysis, expectsExplanation: true)?.isExplanationFailed == true)
    }
}
