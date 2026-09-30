import Foundation
import Testing
@testable import Tangomiru

struct ReadingSegmenterTests {
    let a = UUID()
    let b = UUID()

    @Test func noHighlightsGivesPlainText() {
        #expect(ReadingSegmenter.segments(body: "Hello", highlights: []) == [ReadingSegment(text: "Hello", itemID: nil)])
    }

    @Test func splitsAroundHighlights() {
        let segments = ReadingSegmenter.segments(
            body: "I gave up today.",
            highlights: [ReadingHighlight(span: TextSpan(location: 2, length: 7), itemID: a)]
        )
        #expect(segments == [
            ReadingSegment(text: "I ", itemID: nil),
            ReadingSegment(text: "gave up", itemID: a),
            ReadingSegment(text: " today.", itemID: nil),
        ])
    }

    @Test func prefersLongerOverlappingHighlight() {
        let segments = ReadingSegmenter.segments(
            body: "I gave up today.",
            highlights: [
                ReadingHighlight(span: TextSpan(location: 2, length: 4), itemID: b),
                ReadingHighlight(span: TextSpan(location: 2, length: 7), itemID: a),
            ]
        )
        #expect(segments.compactMap(\.itemID) == [a])
    }

    @Test func ignoresOutOfBoundsHighlights() {
        let segments = ReadingSegmenter.segments(
            body: "short",
            highlights: [ReadingHighlight(span: TextSpan(location: 3, length: 10), itemID: a)]
        )
        #expect(segments == [ReadingSegment(text: "short", itemID: nil)])
    }

    @Test func handlesEmojiOffsets() {
        let segments = ReadingSegmenter.segments(
            body: "😀 give up",
            highlights: [ReadingHighlight(span: TextSpan(location: 3, length: 7), itemID: a)]
        )
        #expect(segments == [ReadingSegment(text: "😀 ", itemID: nil), ReadingSegment(text: "give up", itemID: a)])
    }
}
