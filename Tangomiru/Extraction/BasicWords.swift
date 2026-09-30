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

    /// frequency/2000.txt に含まれない代名詞などの機能語
    static let functionWords: Set<String> = [
        "their", "theirs", "them", "themselves", "our", "ours", "ourselves", "its", "itself",
        "hers", "herself", "himself", "yours", "yourself", "yourselves", "myself", "mine",
        "whose", "whom", "whereas",
    ]
}
