import Foundation

/// 以前の形式（複数の訳や括弧の補足を含む）で保存された意味を、文脈に合う1つの意味に作り直す
enum MeaningMigration {
    static func needsMigration(_ meaning: String) -> Bool {
        meaning.contains(" / ") || MeaningFormatter.single(meaning) != meaning
    }

    static func migrate(_ passage: Passage, tokenizer: Tokenizer, dictionary: any WordDictionary) {
        let targets = passage.items.filter { item in
            needsMigration(item.meaning) || item.distractors.contains(where: needsMigration)
        }
        guard !targets.isEmpty else { return }
        // 品詞は本文を解析し直して、その語の最初の出現位置のトークンから取る
        let tokensByLocation = Dictionary(
            tokenizer.tokenize(passage.body).tokens.map { ($0.span.location, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        for item in targets {
            if needsMigration(item.meaning) {
                let partOfSpeech = item.occurrences.first.flatMap { tokensByLocation[$0.location]?.partOfSpeech }
                let fromDictionary = item.source == .dictionary
                    ? dictionary.meaning(for: item.term, partOfSpeech: item.term.contains(" ") ? nil : partOfSpeech)
                    : nil
                let simplified = fromDictionary ?? MeaningFormatter.single(item.meaning)
                if !simplified.isEmpty { item.meaning = simplified }
            }
            item.distractors = ExtractionPipeline.cleanedDistractors(item.distractors, excluding: item.meaning)
        }
    }
}
