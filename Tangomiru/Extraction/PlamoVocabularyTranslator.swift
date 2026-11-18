import Foundation

nonisolated struct PlamoVocabularyTranslator: Sendable {
    let translator: any SentenceTranslator

    private struct Target {
        let itemIndex: Int
        let span: TextSpan
    }

    /// 出題語に番号付きのタグを付け、文ごとに1回訳して対応する日本語を取り出す。
    func meanings(for items: [ExtractedItem], in body: String, tokenized: TokenizedText) async -> [Int: String] {
        guard translator.isAvailable, !items.isEmpty else { return [:] }
        let sentenceByLocation = Dictionary(tokenized.tokens.map { ($0.span.location, $0.sentenceIndex) }) { first, _ in first }
        var targetsBySentence: [Int: [Target]] = [:]
        for (index, item) in items.enumerated() {
            guard let span = item.occurrences.first, let sentenceIndex = sentenceByLocation[span.location],
                  tokenized.sentenceSpans.indices.contains(sentenceIndex) else { continue }
            targetsBySentence[sentenceIndex, default: []].append(Target(itemIndex: index, span: span))
        }

        let text = body as NSString
        var meanings: [Int: String] = [:]
        for sentenceIndex in targetsBySentence.keys.sorted() {
            if Task.isCancelled { break }
            let sentence = tokenized.sentenceSpans[sentenceIndex]
            let targets = targetsBySentence[sentenceIndex, default: []]
                .filter { $0.span.location >= sentence.location && $0.span.end <= sentence.end }
            guard !targets.isEmpty else { continue }
            let source = NSMutableString(string: text.substring(with: NSRange(location: sentence.location, length: sentence.length)))
            // 原文に同じ形式のタグがある文では、訳語との対応を確定できない。
            guard source.range(of: #"</?v[0-9]+>"#, options: .regularExpression).location == NSNotFound else { continue }
            for (offset, target) in targets.enumerated().reversed() {
                source.insert("</v\(offset + 1)>", at: target.span.end - sentence.location)
                source.insert("<v\(offset + 1)>", at: target.span.location - sentence.location)
            }

            do {
                let translation = try await translator.translate(source.trimmingCharacters(in: .whitespacesAndNewlines))
                for (offset, target) in targets.enumerated() {
                    meanings[target.itemIndex] = Self.meaning(in: translation, tag: offset + 1)
                }
            } catch is CancellationError {
                break
            } catch PlamoError.modelNotFound, PlamoError.loadFailed {
                break
            } catch {
                continue
            }
        }
        return meanings
    }

    private static func meaning(in translation: String, tag: Int) -> String? {
        let parts = translation.components(separatedBy: "<v\(tag)>")
        guard parts.count == 2 else { return nil }
        let tail = parts[1].components(separatedBy: "</v\(tag)>")
        guard tail.count == 2 else { return nil }
        let candidate = tail[0].trimmingCharacters(in: .whitespacesAndNewlines)
        guard candidate.count <= 32, candidate.rangeOfCharacter(from: CharacterSet(charactersIn: "<>。！？").union(.newlines)) == nil else { return nil }
        let formatted = MeaningFormatter.single(candidate)
        return MeaningFormatter.containsJapanese(formatted) ? formatted : nil
    }
}
