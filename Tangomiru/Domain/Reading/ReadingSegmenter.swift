import Foundation
import NaturalLanguage

nonisolated struct ReadingHighlight: Equatable, Sendable {
    let span: TextSpan
    let itemID: UUID
}

nonisolated struct ReadingSegment: Equatable, Sendable {
    let text: String
    /// nil は通常のテキスト
    let itemID: UUID?
}

/// 通常区間を単語とそれ以外（空白・記号・数字）に分けた一片
nonisolated struct WordPiece: Equatable, Sendable {
    let text: String
    let isWord: Bool
}

nonisolated enum ReadingSegmenter {
    /// text を単語（英字を含むもの）とその間に分ける。つなげると text に戻る
    static func wordPieces(_ text: String) -> [WordPiece] {
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.string = text
        var pieces: [WordPiece] = []
        var cursor = text.startIndex
        for range in tokenizer.tokens(for: text.startIndex..<text.endIndex) where text[range].contains(where: \.isLetter) {
            if cursor < range.lowerBound { pieces.append(WordPiece(text: String(text[cursor..<range.lowerBound]), isWord: false)) }
            pieces.append(WordPiece(text: String(text[range]), isWord: true))
            cursor = range.upperBound
        }
        if cursor < text.endIndex { pieces.append(WordPiece(text: String(text[cursor...]), isWord: false)) }
        return pieces
    }

    /// 本文全体のハイライトのうち span に収まるものを、span の先頭を 0 とする位置に直して返す（1文だけを表示するとき用）
    static func highlights(_ highlights: [ReadingHighlight], within span: TextSpan) -> [ReadingHighlight] {
        highlights
            .filter { $0.span.location >= span.location && $0.span.end <= span.end }
            .map { ReadingHighlight(span: TextSpan(location: $0.span.location - span.location, length: $0.span.length), itemID: $0.itemID) }
    }

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
