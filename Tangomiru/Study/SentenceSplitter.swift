import Foundation
import NaturalLanguage

/// 本文から切り出した1文と、その本文中の位置
nonisolated struct SentenceSlice: Equatable, Sendable {
    let text: String
    let span: TextSpan
}

nonisolated enum SentenceSplitter {
    /// 本文を1文ずつに分ける。英字を含まない断片（"..." や数字だけ）は除く
    static func sentences(in text: String) -> [String] {
        slices(in: text).map(\.text)
    }

    /// sentences(in:) と同じ分け方で、本文中の位置（前後の空白を除いた範囲）も返す
    static func slices(in text: String) -> [SentenceSlice] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex).compactMap { range -> SentenceSlice? in
            var lower = range.lowerBound
            var upper = range.upperBound
            while lower < upper, text[lower].isWhitespace { lower = text.index(after: lower) }
            while lower < upper, text[text.index(before: upper)].isWhitespace { upper = text.index(before: upper) }
            let sentence = String(text[lower..<upper])
            guard sentence.contains(where: \.isLetter) else { return nil }
            let ns = NSRange(lower..<upper, in: text)
            return SentenceSlice(text: sentence, span: TextSpan(location: ns.location, length: ns.length))
        }
    }
}
