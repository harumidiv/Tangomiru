import Foundation

enum ContextHighlighter {
    /// 例文中で最初に一致した語を太字にする
    static func attributed(sentence: String, highlight: String) -> AttributedString {
        guard let span = TextSearch.occurrences(of: highlight, in: sentence).first else {
            return AttributedString(sentence)
        }
        let ns = sentence as NSString
        var match = AttributedString(ns.substring(with: NSRange(location: span.location, length: span.length)))
        match.inlinePresentationIntent = .stronglyEmphasized
        return AttributedString(ns.substring(to: span.location))
            + match
            + AttributedString(ns.substring(from: span.end))
    }
}
