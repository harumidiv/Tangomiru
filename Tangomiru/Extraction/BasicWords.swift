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

    /// frequency/2000.txt に含まれない代名詞・冠詞・助動詞の活用形・間投詞などの機能語
    static let functionWords: Set<String> = [
        "an", "my", "your", "his", "her", "its", "our", "their", "me", "us", "him", "them",
        "mine", "yours", "hers", "ours", "theirs",
        "myself", "yourself", "yourselves", "himself", "herself", "itself", "ourselves", "themselves",
        "whose", "whom", "whereas",
        "am", "is", "are", "was", "were", "been", "being", "has", "had", "does", "did", "done",
        "oh", "ah", "hi", "hey", "hello", "ok", "okay", "yeah", "yes", "no", "pm", "re",
        "gonna", "wanna", "gotta",
    ]
}
