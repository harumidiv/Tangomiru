import Foundation
import NaturalLanguage

nonisolated enum SentenceSplitter {
    /// 本文を1文ずつに分ける。英字を含まない断片（"..." や数字だけ）は除く
    static func sentences(in text: String) -> [String] {
        let tokenizer = NLTokenizer(unit: .sentence)
        tokenizer.string = text
        return tokenizer.tokens(for: text.startIndex..<text.endIndex)
            .map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.contains(where: \.isLetter) }
    }
}
