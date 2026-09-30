import Foundation
import SwiftData

/// 「1文ずつ学ぶ」で初めて開いたときに作って保存した和訳と解説
@Model
final class StoredSentenceAnalysis {
    var sentence: String
    var translation: String
    var explanation: String
    var passage: Passage?

    init(sentence: String, analysis: SentenceAnalysis) {
        self.sentence = sentence
        self.translation = analysis.translation
        self.explanation = analysis.explanation
    }

    var value: SentenceAnalysis {
        SentenceAnalysis(translation: translation, explanation: explanation)
    }
}
