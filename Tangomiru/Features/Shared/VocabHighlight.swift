import SwiftUI

extension Passage {
    /// 本文中でハイライトする単語の位置（習得済みとオフにした単語は除く）
    var readingHighlights: [ReadingHighlight] {
        enabledItems
            .filter { $0.state != .mastered }
            .flatMap { item in item.occurrences.map { ReadingHighlight(span: $0, itemID: item.uuid) } }
    }

    var itemsByID: [UUID: VocabItem] {
        Dictionary(items.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
    }
}

enum VocabHighlight {
    /// text に単語のハイライトとリンク（ReadingLink）を付ける。highlights の位置は text に対するもの
    static func attributed(_ text: String, highlights: [ReadingHighlight], itemsByID: [UUID: VocabItem]) -> AttributedString {
        var result = AttributedString()
        for segment in ReadingSegmenter.segments(body: text, highlights: highlights) {
            var part = AttributedString(segment.text)
            if let id = segment.itemID, let item = itemsByID[id] {
                part.backgroundColor = item.state.highlightBackground
                part.link = ReadingLink.url(for: id)
                if item.state == .veryWeak {
                    part.inlinePresentationIntent = .stronglyEmphasized
                }
            }
            result += part
        }
        return result
    }
}

extension View {
    /// ハイライトした単語のタップを受け取り、その単語を onSelect に渡す
    func onVocabTap(itemsByID: [UUID: VocabItem], onSelect: @escaping (VocabItem) -> Void) -> some View {
        tint(.primary)
            .textSelection(.disabled)
            .environment(\.openURL, OpenURLAction { url in
                if let id = ReadingLink.itemID(from: url), let item = itemsByID[id] {
                    onSelect(item)
                }
                return .handled
            })
    }
}

/// タップした単語の意味と例文を出すシート
struct ItemDetailSheet: View {
    let item: VocabItem
    @State private var speaker = WordSpeaker()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.term).font(.title2.bold())
                MasteryBadge(state: item.state)
                Spacer()
                Button {
                    speaker.speak(item.term)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("\(item.term) を読み上げる")
            }
            Text(item.meaning).font(.body)
            Text(item.contextSentence).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .onDisappear { speaker.stop() }
    }
}
