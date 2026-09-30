import Foundation

nonisolated enum PassageInput {
    static let maxLength = 10_000
    static let autoTitleLength = 30

    enum Problem: Equatable {
        case empty
        case tooLong
    }

    static func validate(_ body: String) -> Problem? {
        if body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { return .empty }
        if body.count > maxLength { return .tooLong }
        return nil
    }

    /// タイトル未入力なら本文の最初の空でない行から作る
    static func title(_ title: String, body: String) -> String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let firstLine = body.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .first { !$0.isEmpty } ?? ""
        guard firstLine.count > autoTitleLength else { return firstLine }
        return String(firstLine.prefix(autoTitleLength)) + "…"
    }
}
