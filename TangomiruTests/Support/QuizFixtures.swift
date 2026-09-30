import Foundation
@testable import Tangomiru

nonisolated func makeCard(_ term: String, score: Int?, distractors: [String] = []) -> QuizCard {
    QuizCard(
        id: UUID(),
        term: term,
        meaning: "\(term)の意味",
        distractors: distractors,
        contextSentence: "This is \(term).",
        highlight: term,
        score: score
    )
}
