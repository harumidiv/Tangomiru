import Foundation

nonisolated enum TextSearch {
    /// 大文字小文字を無視し、前後が英字でない位置で一致した出現をすべて返す（UTF-16 単位）
    static func occurrences(of term: String, in text: String) -> [TextSpan] {
        guard !term.isEmpty else { return [] }
        let ns = text as NSString
        var result: [TextSpan] = []
        var searchStart = 0
        while searchStart < ns.length {
            let found = ns.range(
                of: term, options: [.caseInsensitive],
                range: NSRange(location: searchStart, length: ns.length - searchStart)
            )
            guard found.location != NSNotFound else { break }
            if isBoundary(ns, at: found.location - 1) && isBoundary(ns, at: found.location + found.length) {
                result.append(TextSpan(location: found.location, length: found.length))
            }
            searchStart = found.location + 1
        }
        return result
    }

    private static func isBoundary(_ ns: NSString, at index: Int) -> Bool {
        guard index >= 0, index < ns.length, let scalar = UnicodeScalar(ns.character(at: index)) else { return true }
        return !CharacterSet.letters.contains(scalar)
    }
}
