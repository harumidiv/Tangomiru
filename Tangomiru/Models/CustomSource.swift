import Foundation
import SwiftData

/// 「英文を探す」に自分で追加したサイト
@Model
final class CustomSource {
    var name: String
    var url: URL
    var createdAt: Date

    init(name: String, url: URL, createdAt: Date = .now) {
        self.name = name
        self.url = url
        self.createdAt = createdAt
    }

    /// 入力された URL を整える。スキームが無ければ https を付け、http(s) でドメインのある URL だけを受け付ける
    nonisolated static func normalizedURL(from input: String) -> URL? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isWhitespace) else { return nil }
        let withScheme = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let url = URL(string: withScheme),
              let scheme = url.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = url.host(), host.contains(".") else { return nil }
        return url
    }
}
