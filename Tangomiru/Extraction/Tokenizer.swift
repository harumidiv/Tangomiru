import Foundation
import NaturalLanguage

nonisolated struct Token: Equatable, Sendable {
    let surface: String
    /// 小文字の原形。取れない場合は表層形の小文字
    let lemma: String
    let span: TextSpan
    let sentenceIndex: Int
    let isProperNoun: Bool
    /// 直前のトークンとの間が空白だけなら true（熟語照合で句読点をまたがないため）
    let followsPreviousDirectly: Bool
    var partOfSpeech: PartOfSpeech = .other
}

nonisolated struct TokenizedText: Equatable, Sendable {
    let tokens: [Token]
    let sentences: [String]
}

nonisolated struct Tokenizer: Sendable {
    private static let nameTags: Set<NLTag> = [.personalName, .placeName, .organizationName]

    func tokenize(_ text: String) -> TokenizedText {
        let fullRange = text.startIndex..<text.endIndex

        let sentenceTokenizer = NLTokenizer(unit: .sentence)
        sentenceTokenizer.string = text
        let sentenceRanges = sentenceTokenizer.tokens(for: fullRange)
        let sentences = sentenceRanges.map { text[$0].trimmingCharacters(in: .whitespacesAndNewlines) }

        let tagger = NLTagger(tagSchemes: [.lemma, .nameType, .lexicalClass])
        tagger.string = text
        var tokens: [Token] = []
        var sentenceIndex = 0
        var previousEnd: String.Index?

        tagger.enumerateTags(
            in: fullRange, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            while sentenceIndex + 1 < sentenceRanges.count && sentenceRanges[sentenceIndex].upperBound <= range.lowerBound {
                sentenceIndex += 1
            }
            let surface = String(text[range])
            let lemma = tag.map { $0.rawValue.lowercased() }.flatMap { $0.isEmpty ? nil : $0 } ?? surface.lowercased()
            let (nameTag, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .nameType)
            let (lexicalClass, _) = tagger.tag(at: range.lowerBound, unit: .word, scheme: .lexicalClass)
            let followsPrevious = previousEnd.map { text[$0..<range.lowerBound].allSatisfy(\.isWhitespace) } ?? false
            let nsRange = NSRange(range, in: text)
            tokens.append(Token(
                surface: surface,
                lemma: lemma,
                span: TextSpan(location: nsRange.location, length: nsRange.length),
                sentenceIndex: sentenceIndex,
                isProperNoun: nameTag.map { Self.nameTags.contains($0) } ?? false,
                followsPreviousDirectly: followsPrevious,
                partOfSpeech: Self.partOfSpeech(for: lexicalClass)
            ))
            previousEnd = range.upperBound
            return true
        }
        return TokenizedText(tokens: tokens, sentences: sentences)
    }

    private static func partOfSpeech(for tag: NLTag?) -> PartOfSpeech {
        switch tag {
        case .noun?: .noun
        case .verb?: .verb
        case .adjective?: .adjective
        default: .other
        }
    }
}
