import Foundation

/// 出題から除外する基本語（EJDict frequency/2000.txt）
nonisolated enum BasicWords {
    static func parse(_ text: String) -> Set<String> {
        Set(
            text.split(whereSeparator: \.isNewline)
                .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    static func loadBundled(bundle: Bundle = .main) throws -> Set<String> {
        guard let url = bundle.url(forResource: "basic_words", withExtension: "txt") else {
            throw ResourceError.missing("basic_words.txt")
        }
        return parse(try String(contentsOf: url, encoding: .utf8)).union(functionWords)
    }

    /// 基本語を出題に含める場合でも除外する機能語（冠詞・代名詞・be/have/do・助動詞・前置詞・接続詞・間投詞など）。
    /// frequency/2000.txt に無い語（their, an など）もここで補う
    static let functionWords: Set<String> = [
        // 冠詞・限定詞
        "a", "an", "the", "this", "that", "these", "those", "some", "any", "no", "every", "each", "all", "both",
        "either", "neither", "such", "other", "another", "much", "many", "more", "most", "few", "little", "less",
        // 代名詞
        "i", "me", "my", "mine", "myself", "you", "your", "yours", "yourself", "yourselves",
        "he", "him", "his", "himself", "she", "her", "hers", "herself", "it", "its", "itself",
        "we", "us", "our", "ours", "ourselves", "they", "them", "their", "theirs", "themselves",
        "one", "someone", "something", "anyone", "anything", "everyone", "everything", "nobody", "nothing",
        "who", "whom", "whose", "what", "which", "when", "where", "why", "how", "whether", "whereas",
        // be・have・do・助動詞
        "be", "am", "is", "are", "was", "were", "been", "being",
        "have", "has", "had", "having", "do", "does", "did", "done", "doing",
        "can", "could", "will", "would", "shall", "should", "may", "might", "must",
        // 前置詞
        "of", "in", "on", "at", "to", "for", "with", "from", "by", "about", "as", "into", "onto", "over", "under",
        "up", "down", "out", "off", "through", "after", "before", "between", "during", "without", "within",
        "against", "among", "around", "behind", "below", "above", "across", "along", "near", "since", "until", "upon",
        // 接続詞・副詞
        "and", "or", "but", "nor", "so", "yet", "if", "than", "then", "because", "though", "although", "while",
        "not", "very", "too", "also", "just", "only", "even", "there", "here", "now", "again", "still",
        // 間投詞・口語
        "oh", "ah", "hi", "hey", "hello", "ok", "okay", "yeah", "yes", "pm", "re", "gonna", "wanna", "gotta",
    ]

    /// 抽出で除外する語。includeBasicWords が true なら機能語だけを除外する
    static func excludedWords(basic: Set<String>, includeBasicWords: Bool) -> Set<String> {
        includeBasicWords ? functionWords : basic
    }
}
