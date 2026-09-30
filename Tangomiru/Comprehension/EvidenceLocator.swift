import Foundation

/// 根拠の英文が本文のどの文にあるかを探す（内容理解クイズで本文の該当文をハイライトするため）
nonisolated enum EvidenceLocator {
    static func sentenceIndex(of evidence: String?, in sentences: [String]) -> Int? {
        guard let evidence = evidence?.trimmingCharacters(in: .whitespacesAndNewlines), !evidence.isEmpty else { return nil }
        // 根拠が1文の一部ならその文、複数の文にまたがるならその最初の文
        return sentences.firstIndex { $0.range(of: evidence, options: .caseInsensitive) != nil }
            ?? sentences.firstIndex { evidence.range(of: $0, options: .caseInsensitive) != nil }
    }
}
