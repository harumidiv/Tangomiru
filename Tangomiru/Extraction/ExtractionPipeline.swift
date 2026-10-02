import Foundation

nonisolated struct ExtractionResult: Hashable, Sendable {
    let items: [ExtractedItem]
    /// 1チャンク以上で AI の上乗せに成功したか
    let usedAI: Bool
    /// 抽出と一緒に作った内容理解の問題（Apple Intelligence 対応端末のみ）
    var comprehension: [ComprehensionQuestion] = []
}

nonisolated struct ExtractionPipeline: Sendable {
    static let chunkSize = 15
    static let maxDistractors = 3
    static let maxSentenceLength = 300

    let extractor: DictionaryExtractor
    let enricher: (any VocabEnricher)?
    private let tokenizer = Tokenizer()

    init(extractor: DictionaryExtractor, enricher: (any VocabEnricher)?) {
        self.extractor = extractor
        self.enricher = enricher
    }

    @concurrent
    func run(_ body: String) async -> ExtractionResult {
        let tokenized = tokenizer.tokenize(body)
        var items = extractor.extract(from: tokenized)
        guard let enricher, enricher.isAvailable, !items.isEmpty else {
            return ExtractionResult(items: items, usedAI: false)
        }

        let dictionaryMeanings = items.map(\.meaning)
        var usedAI = false
        var idioms: [EnrichedEntry] = []
        for start in stride(from: 0, to: items.count, by: Self.chunkSize) {
            // キャンセルされたら残りのチャンクは AI に投げず、辞書の結果で返す
            if Task.isCancelled { break }
            let range = start..<min(start + Self.chunkSize, items.count)
            let inputs = items[range].map {
                EnrichmentInput(term: $0.term, contextSentence: $0.contextSentence, dictionaryMeaning: $0.meaning)
            }
            var sentences: [String] = []
            for input in inputs {
                let sentence = String(input.contextSentence.prefix(Self.maxSentenceLength))
                if !sentences.contains(sentence) { sentences.append(sentence) }
            }
            do {
                let output = try await enricher.enrich(inputs, sentences: sentences)
                usedAI = true
                for index in range {
                    Self.apply(output.words, to: &items[index])
                }
                idioms += output.idioms
            } catch {
                // このチャンクは辞書の結果のまま進める
                continue
            }
        }

        Self.resolveDuplicateMeanings(&items, dictionaryMeanings: dictionaryMeanings)
        let existingTerms = Set(items.map { $0.term.lowercased() })
        items += Self.validatedIdioms(idioms, body: body, sentences: tokenized.sentences, existingTerms: existingTerms)
        items.sort { $0.firstLocation < $1.firstLocation }
        return ExtractionResult(items: items, usedAI: usedAI)
    }

    static func apply(_ entries: [EnrichedEntry], to item: inout ExtractedItem) {
        guard let entry = entries.first(where: { $0.term.lowercased() == item.term.lowercased() }) else { return }
        let meaning = MeaningFormatter.single(entry.meaning)
        if !meaning.isEmpty { item.meaning = meaning }
        item.distractors = cleanedDistractors(entry.distractors, excluding: item.meaning)
    }

    /// AI が別々の語に同じ訳を付けた場合（例: return と dividend が両方「配当」）、
    /// 辞書の訳と一致する語はその訳を残し、それ以外は辞書の訳に戻す。
    /// どれも辞書と一致しなければ、本文で最初に出てきた語だけ AI の訳を残す
    static func resolveDuplicateMeanings(_ items: inout [ExtractedItem], dictionaryMeanings: [String]) {
        let groups = Dictionary(grouping: items.indices, by: { items[$0].meaning })
        for (meaning, indices) in groups where indices.count > 1 {
            let ordered = indices.sorted { items[$0].firstLocation < items[$1].firstLocation }
            let keeper = ordered.first { dictionaryMeanings[$0] == meaning } ?? ordered[0]
            for index in ordered where index != keeper {
                items[index].meaning = dictionaryMeanings[index]
                items[index].distractors = cleanedDistractors(items[index].distractors, excluding: items[index].meaning)
            }
        }
    }

    static func cleanedDistractors(_ raw: [String], excluding meaning: String) -> [String] {
        var result: [String] = []
        for distractor in raw {
            // 正解と見た目を揃えるため、誤答も補足を除いた1語にする
            let trimmed = MeaningFormatter.single(distractor)
            if MeaningFormatter.containsJapanese(trimmed) && trimmed != meaning && !result.contains(trimmed) {
                result.append(trimmed)
            }
        }
        return Array(result.prefix(maxDistractors))
    }

    /// 本文中に実在する2語以上の熟語だけを採用する
    static func validatedIdioms(
        _ idioms: [EnrichedEntry], body: String, sentences: [String], existingTerms: Set<String>
    ) -> [ExtractedItem] {
        var seen = existingTerms
        var result: [ExtractedItem] = []
        for idiom in idioms {
            let term = idiom.term.trimmingCharacters(in: .whitespacesAndNewlines)
            let meaning = MeaningFormatter.single(idiom.meaning)
            let key = term.lowercased()
            guard term.contains(" "), !meaning.isEmpty, !seen.contains(key) else { continue }
            let spans = TextSearch.occurrences(of: term, in: body)
            guard !spans.isEmpty else { continue }
            seen.insert(key)
            let sentence = sentences.first { !TextSearch.occurrences(of: term, in: $0).isEmpty } ?? ""
            result.append(ExtractedItem(
                term: key,
                meaning: meaning,
                distractors: cleanedDistractors(idiom.distractors, excluding: meaning),
                contextSentence: sentence,
                occurrences: spans,
                source: .ai
            ))
        }
        return result
    }
}
