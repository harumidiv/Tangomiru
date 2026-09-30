import SwiftUI

struct ReadingView: View {
    let passage: Passage
    @State private var selectedItem: VocabItem?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                legend
                Text(attributedBody)
                    .font(.body)
                    .lineSpacing(6)
                    .tint(.primary)
                    .textSelection(.disabled)
                    .environment(\.openURL, OpenURLAction { url in
                        if let id = ReadingLink.itemID(from: url) {
                            selectedItem = passage.items.first { $0.uuid == id }
                        }
                        return .handled
                    })
            }
            .padding()
        }
        .navigationTitle("読解モード")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(item: item)
                .presentationDetents([.height(240)])
        }
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach([MasteryState.veryWeak, .weak, .vague, .unseen]) { state in
                MasteryBadge(state: state)
            }
            Spacer()
            Text("\(passage.stats.percentText) 習得").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var attributedBody: AttributedString {
        let itemsByID = Dictionary(passage.items.map { ($0.uuid, $0) }, uniquingKeysWith: { first, _ in first })
        let highlights = passage.enabledItems
            .filter { $0.state != .mastered }
            .flatMap { item in item.occurrences.map { ReadingHighlight(span: $0, itemID: item.uuid) } }
        var result = AttributedString()
        for segment in ReadingSegmenter.segments(body: passage.body, highlights: highlights) {
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

private struct ItemDetailSheet: View {
    let item: VocabItem

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(item.term).font(.title2.bold())
                MasteryBadge(state: item.state)
            }
            Text(item.meaning).font(.body)
            Text(item.contextSentence).font(.callout).foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
