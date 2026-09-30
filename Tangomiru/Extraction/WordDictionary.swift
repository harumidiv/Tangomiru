import Foundation

nonisolated protocol WordDictionary: Sendable {
    /// 小文字の見出し語（熟語は半角スペース区切り）で引き、表示用に整形した訳を返す
    func meaning(for key: String) -> String?
    /// 誤答の補充用に、単語（熟語以外）の訳をランダムに返す
    func randomMeanings(count: Int, using rng: inout SeededRandom) -> [String]
}

nonisolated enum ResourceError: Error, Equatable {
    case missing(String)
}

nonisolated struct EJDictionary: WordDictionary {
    /// 小文字見出し → EJDict の生の訳（整形は引くときに行う）
    private let rawEntries: [String: String]
    private let keys: [String]

    init(tsv: String) {
        var entries: [String: String] = [:]
        for line in tsv.split(separator: "\n", omittingEmptySubsequences: true) {
            let parts = line.split(separator: "\t", maxSplits: 1)
            guard parts.count == 2 else { continue }
            let raw = String(parts[1])
            for headword in parts[0].split(separator: ",") {
                let head = headword.trimmingCharacters(in: .whitespaces)
                // 大文字を含む見出し（固有名詞・略語: "Polish", "OK", "PM", "WO" など）は使わない。
                // 本文の語は小文字化して引くため、"ok" が「オクラホマ州」になるような誤訳を防ぐ
                guard !head.isEmpty, head == head.lowercased(), entries[head] == nil else { continue }
                entries[head] = raw
            }
        }
        rawEntries = entries
        keys = entries.keys.sorted()
    }

    static func loadBundled(bundle: Bundle = .main) throws -> EJDictionary {
        guard let url = bundle.url(forResource: "ejdict", withExtension: "tsv") else {
            throw ResourceError.missing("ejdict.tsv")
        }
        return EJDictionary(tsv: try String(contentsOf: url, encoding: .utf8))
    }

    var count: Int { rawEntries.count }

    func meaning(for key: String) -> String? {
        guard let raw = rawEntries[key] else { return nil }
        let formatted = MeaningFormatter.format(raw)
        return formatted.isEmpty ? nil : formatted
    }

    func randomMeanings(count: Int, using rng: inout SeededRandom) -> [String] {
        guard !keys.isEmpty else { return [] }
        var result: [String] = []
        var attempts = 0
        while result.count < count && attempts < count * 10 {
            attempts += 1
            let key = keys[Int.random(in: 0..<keys.count, using: &rng)]
            guard !key.contains(" "), let meaning = meaning(for: key), !result.contains(meaning) else { continue }
            result.append(meaning)
        }
        return result
    }
}
