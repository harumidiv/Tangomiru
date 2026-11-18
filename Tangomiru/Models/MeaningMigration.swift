import Foundation

/// 保存された旧形式の訳と、修正済みの辞書訳を更新する
enum MeaningMigration {
    static func needsMigration(_ meaning: String) -> Bool {
        meaning.contains(" / ") || MeaningFormatter.single(meaning) != meaning
            || !MeaningFormatter.containsJapanese(meaning)
    }

    private static func usesOutdatedDictionaryMeaning(_ item: VocabItem) -> Bool {
        switch (item.term.lowercased(), item.meaning) {
        case ("client", "弁護"), ("clients", "弁護"), ("global", "球の"): true
        default: false
        }
    }

    static func migrate(_ passage: Passage, tokenizer: Tokenizer, dictionary: any WordDictionary) {
        let targets = passage.items.filter { item in
            needsMigration(item.meaning) || usesOutdatedDictionaryMeaning(item)
                || item.distractors.contains { needsMigration($0) }
        }
        guard !targets.isEmpty else { return }
        // 品詞は本文を解析し直して、その語の最初の出現位置のトークンから取る
        let tokensByLocation = Dictionary(
            tokenizer.tokenize(passage.body).tokens.map { ($0.span.location, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for item in targets {
            let outdated = usesOutdatedDictionaryMeaning(item)
            if needsMigration(item.meaning) || outdated {
                let partOfSpeech = item.occurrences.first.flatMap { tokensByLocation[$0.location]?.partOfSpeech }
                let fromDictionary = item.source == .dictionary || outdated
                    ? dictionary.meaning(for: item.term.lowercased(), partOfSpeech: item.term.contains(" ") ? nil : partOfSpeech)
                    : nil
                let simplified = fromDictionary ?? MeaningFormatter.single(item.meaning)
                if !simplified.isEmpty { item.meaning = simplified }
            }
            item.distractors = ExtractionPipeline.cleanedDistractors(item.distractors, excluding: item.meaning)
        }
    }
}
