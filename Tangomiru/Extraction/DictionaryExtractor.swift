import Foundation

/// トークン列を辞書と照合し、熟語（最長一致優先）と単語を抽出する
nonisolated struct DictionaryExtractor: Sendable {
    static let maxPhraseLength = 4

    let dictionary: any WordDictionary
    let basicWords: Set<String>

    private struct Match {
        let term: String
        let meaning: String
        let length: Int
    }

    func extract(from text: TokenizedText) -> [ExtractedItem] {
        let tokens = text.tokens
        var itemsByTerm: [String: ExtractedItem] = [:]

        func record(_ term: String, meaning: String, span: TextSpan, sentenceIndex: Int) {
            if itemsByTerm[term] != nil {
                itemsByTerm[term]?.occurrences.append(span)
                return
            }
            let sentence = text.sentences.indices.contains(sentenceIndex) ? text.sentences[sentenceIndex] : ""
            itemsByTerm[term] = ExtractedItem(
                term: term, meaning: meaning, distractors: [], contextSentence: sentence,
                occurrences: [span], source: .dictionary
            )
        }

        var index = 0
        while index < tokens.count {
            if let match = longestPhrase(startingAt: index, in: tokens) {
                let first = tokens[index]
                let last = tokens[index + match.length - 1]
                let span = TextSpan(location: first.span.location, length: last.span.end - first.span.location)
                record(match.term, meaning: match.meaning, span: span, sentenceIndex: first.sentenceIndex)
                index += match.length
                continue
            }
            if let match = wordMatch(for: tokens[index]) {
                record(match.term, meaning: match.meaning, span: tokens[index].span, sentenceIndex: tokens[index].sentenceIndex)
            }
            index += 1
        }
        return itemsByTerm.values.sorted { $0.firstLocation < $1.firstLocation }
    }

    private func longestPhrase(startingAt start: Int, in tokens: [Token]) -> Match? {
        let maxLength = min(Self.maxPhraseLength, tokens.count - start)
        guard maxLength >= 2 else { return nil }
        for length in stride(from: maxLength, through: 2, by: -1) {
            let slice = Array(tokens[start..<start + length])
            let isContiguous = slice.dropFirst().allSatisfy {
                $0.followsPreviousDirectly && $0.sentenceIndex == slice[0].sentenceIndex
            }
            guard isContiguous, !slice.contains(where: \.isProperNoun) else { continue }
            for key in Self.phraseKeys(for: slice) {
                if let meaning = dictionary.meaning(for: key) {
                    return Match(term: key, meaning: meaning, length: length)
                }
            }
        }
        return nil
    }

    private func wordMatch(for token: Token) -> Match? {
        let surface = token.surface.lowercased()
        guard !token.isProperNoun, Self.isWordLike(token.lemma),
              !basicWords.contains(token.lemma), !basicWords.contains(surface) else { return nil }
        for key in [token.lemma, surface] {
            if let meaning = dictionary.meaning(for: key) {
                return Match(term: key, meaning: meaning, length: 1)
            }
        }
        return nil
    }

    /// 各トークンの表層形（小文字）と原形の組み合わせを、表層形優先で列挙する（例: "took off", "take off"）
    static func phraseKeys(for tokens: [Token]) -> [String] {
        var keys: [[String]] = [[]]
        for token in tokens {
            let surface = token.surface.lowercased()
            let forms = surface == token.lemma ? [surface] : [surface, token.lemma]
            keys = keys.flatMap { prefix in forms.map { prefix + [$0] } }
        }
        return keys.map { $0.joined(separator: " ") }
    }

    /// 2文字以上で英字から始まり、英字・ハイフン・アポストロフィのみ。
    /// 短縮形の断片（"n't" や "'s"）を除くため、アポストロフィの前に英字が2文字以上あることも求める
    static func isWordLike(_ word: String) -> Bool {
        guard word.count >= 2, let first = word.first, first.isLetter else { return false }
        let isApostrophe: (Character) -> Bool = { $0 == "'" || $0 == "’" }
        guard word.allSatisfy({ $0.isLetter || $0 == "-" || isApostrophe($0) }) else { return false }
        guard let apostrophe = word.firstIndex(where: isApostrophe) else { return true }
        return word.distance(from: word.startIndex, to: apostrophe) >= 2
    }
}
