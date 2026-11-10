import Foundation

/// 本文中リンク。覚える単語は tangomiru://item/<UUID>、それ以外の単語は tangomiru://word?text=<単語>
nonisolated enum ReadingLink {
    static let scheme = "tangomiru"
    static let host = "item"
    static let wordHost = "word"

    static func url(for id: UUID) -> URL {
        URL(string: "\(scheme)://\(host)/\(id.uuidString)")!
    }

    static func itemID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }

    static func url(forWord word: String) -> URL {
        var components = URLComponents()
        components.scheme = scheme
        components.host = wordHost
        components.queryItems = [URLQueryItem(name: "text", value: word)]
        return components.url!
    }

    static func word(from url: URL) -> String? {
        guard url.scheme == scheme, url.host() == wordHost else { return nil }
        return URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems?.first { $0.name == "text" }?.value
    }
}
