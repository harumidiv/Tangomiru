/// 本文中の位置（UTF-16 単位。NSRange と同じ）
nonisolated struct TextSpan: Codable, Hashable, Sendable {
    var location: Int
    var length: Int

    var end: Int { location + length }

    func overlaps(_ other: TextSpan) -> Bool {
        location < other.end && other.location < end
    }
}
