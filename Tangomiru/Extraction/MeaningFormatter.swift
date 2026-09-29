import Foundation

/// EJDict の訳（" / " 区切り、『』強調、《》注記、〈C〉〈U〉タグ付き）を表示用に整える
nonisolated enum MeaningFormatter {
    static let maxSenses = 2

    static func format(_ raw: String) -> String {
        var senses: [String] = []
        for sense in raw.components(separatedBy: " / ") {
            let cleaned = clean(sense)
            if !cleaned.isEmpty && !senses.contains(cleaned) {
                senses.append(cleaned)
            }
            if senses.count == maxSenses { break }
        }
        return senses.joined(separator: " / ")
    }

    static func clean(_ sense: String) -> String {
        var result = ""
        var annotationDepth = 0
        for character in sense {
            switch character {
            case "《": annotationDepth += 1
            case "》": annotationDepth = max(0, annotationDepth - 1)
            case "『", "』": continue
            default:
                if annotationDepth == 0 { result.append(character) }
            }
        }
        for tag in ["〈C〉", "〈U〉"] {
            result = result.replacingOccurrences(of: tag, with: "")
        }
        return result.trimmingCharacters(in: .whitespaces)
    }
}
