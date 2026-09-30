import Foundation

/// 読解モードの本文中リンク（tangomiru://item/<UUID>）
nonisolated enum ReadingLink {
    static let scheme = "tangomiru"
    static let host = "item"

    static func url(for id: UUID) -> URL {
        URL(string: "\(scheme)://\(host)/\(id.uuidString)")!
    }

    static func itemID(from url: URL) -> UUID? {
        guard url.scheme == scheme, url.host() == host else { return nil }
        return UUID(uuidString: url.lastPathComponent)
    }
}
