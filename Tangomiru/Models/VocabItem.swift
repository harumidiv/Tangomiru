import Foundation
import SwiftData

@Model
final class VocabItem {
    var uuid: UUID
    var term: String
    var meaning: String
    var distractors: [String]
    var contextSentence: String
    var occurrences: [TextSpan]
    var isEnabled: Bool
    /// nil=未学習, -1=超苦手, 0=苦手, 1=うろ覚え, 2=覚えた
    var score: Int?
    var source: ItemSource
    var passage: Passage?

    init(extracted: ExtractedItem, isEnabled: Bool = true) {
        uuid = UUID()
        term = extracted.term
        meaning = extracted.meaning
        distractors = extracted.distractors
        contextSentence = extracted.contextSentence
        occurrences = extracted.occurrences
        self.isEnabled = isEnabled
        score = nil
        source = extracted.source
    }
}

extension VocabItem {
    var state: MasteryState { MasteryState(score: score) }

    var firstLocation: Int { occurrences.first?.location ?? .max }

    func quizCard(body: String) -> QuizCard {
        let ns = body as NSString
        var highlight = term
        if let span = occurrences.first, span.location >= 0, span.length > 0, span.end <= ns.length {
            highlight = ns.substring(with: NSRange(location: span.location, length: span.length))
        }
        return QuizCard(
            id: uuid, term: term, meaning: meaning, distractors: distractors,
            contextSentence: contextSentence, highlight: highlight, score: score
        )
    }
}
