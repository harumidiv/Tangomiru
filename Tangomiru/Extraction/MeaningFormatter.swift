import Foundation

nonisolated enum PartOfSpeech: String, Hashable, Sendable {
    case noun
    case verb
    case adjective
    case other
}

/// EJDict の訳（" / " 区切り、『』強調、《》注記、〈〉(…) 補足付き）から、表示用の意味を1つだけ取り出す
nonisolated enum MeaningFormatter {
    private static let brackets: [Character: Character] = ["《": "》", "〈": "〉", "(": ")", "（": "）"]
    private static let separators: Set<Character> = [",", ";", "、", "，", "；"]
    private static let particles: Set<Character> = ["を", "に", "が", "と", "で", "へ"]

    /// 品詞に合う訳を優先して選び、意味を1つだけ返す。
    /// EJDict では名詞の訳に 〈C〉〈U〉 が付くので、それを手がかりに名詞と動詞・形容詞の訳を分ける
    static func format(_ raw: String, partOfSpeech: PartOfSpeech? = nil) -> String {
        let senses = raw.components(separatedBy: " / ")
        let preferred: [String]
        switch partOfSpeech {
        case .noun: preferred = senses.filter(isNounSense)
        case .verb, .adjective: preferred = senses.filter { !isNounSense($0) }
        case .other, nil: preferred = []
        }
        for sense in preferred + senses {
            let meaning = single(sense)
            if !meaning.isEmpty { return meaning }
        }
        return ""
    }

    /// 括弧の補足を取り除き、意味を1つだけ返す（AI の出力にも使う）。
    /// EJDict は代表的な訳を『』で囲むので、あればその中身を使う。無ければカンマ等で区切られた最初の1語
    static func single(_ sense: String) -> String {
        let cleaned = removeAnnotations(sense)
        if let open = cleaned.firstIndex(of: "『"),
           let close = cleaned[open...].firstIndex(of: "』") {
            let emphasized = cleaned[cleaned.index(after: open)..<close].trimmingCharacters(in: .whitespaces)
            if !emphasized.isEmpty { return emphasized }
        }
        let plain = cleaned.replacingOccurrences(of: "『", with: "").replacingOccurrences(of: "』", with: "")
        let first = plain.split(whereSeparator: { separators.contains($0) }).first.map(String.init) ?? ""
        let startsWithAnnotation = sense.first.map { brackets[$0] != nil } ?? false
        return dropLeftoverParticle(first.trimmingCharacters(in: .whitespaces), afterAnnotation: startsWithAnnotation)
    }

    /// "…を変える" や（〈記憶など〉を取り除いた後の）"を呼び起こす" の先頭に残る「…」と助詞を落とす
    private static func dropLeftoverParticle(_ text: String, afterAnnotation: Bool) -> String {
        var result = Substring(text)
        var removedEllipsis = false
        while result.first == "…" {
            result = result.dropFirst()
            removedEllipsis = true
        }
        if (removedEllipsis || afterAnnotation), let first = result.first, particles.contains(first), result.count > 1 {
            result = result.dropFirst()
        }
        return String(result).trimmingCharacters(in: .whitespaces)
    }

    private static func isNounSense(_ sense: String) -> Bool {
        sense.contains("〈C〉") || sense.contains("〈U〉")
    }

    private static func removeAnnotations(_ sense: String) -> String {
        var result = ""
        var closers: [Character] = []
        for character in sense {
            if let closer = brackets[character] {
                closers.append(closer)
            } else if character == closers.last {
                closers.removeLast()
            } else if closers.isEmpty {
                result.append(character)
            }
        }
        return result
    }
}
