import Foundation

nonisolated struct ReadingHighlight: Equatable, Sendable {
    let span: TextSpan
    let itemID: UUID
}

nonisolated struct ReadingSegment: Equatable, Sendable {
    let text: String
    /// nil は通常のテキスト
    let itemID: UUID?
}

nonisolated enum ReadingSegmenter {
    /// 本文をハイライト区間と通常区間に分ける。重なる区間は長い方（熟語）を優先する
    static func segments(body: String, highlights: [ReadingHighlight]) -> [ReadingSegment] {
        let ns = body as NSString
        let candidates = highlights
            .filter { $0.span.location >= 0 && $0.span.length > 0 && $0.span.end <= ns.length }
            .sorted { $0.span.length != $1.span.length ? $0.span.length > $1.span.length : $0.span.location < $1.span.location }
        var accepted: [ReadingHighlight] = []
        for highlight in candidates where !accepted.contains(where: { $0.span.overlaps(highlight.span) }) {
            accepted.append(highlight)
        }
        accepted.sort { $0.span.location < $1.span.location }

        var segments: [ReadingSegment] = []
        var cursor = 0
        for highlight in accepted {
            if highlight.span.location > cursor {
                let plain = NSRange(location: cursor, length: highlight.span.location - cursor)
                segments.append(ReadingSegment(text: ns.substring(with: plain), itemID: nil))
            }
            let range = NSRange(location: highlight.span.location, length: highlight.span.length)
            segments.append(ReadingSegment(text: ns.substring(with: range), itemID: highlight.itemID))
            cursor = highlight.span.end
        }
        if cursor < ns.length {
            segments.append(ReadingSegment(text: ns.substring(from: cursor), itemID: nil))
        }
        return segments
    }
}
