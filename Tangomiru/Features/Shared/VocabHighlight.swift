import SwiftUI
import Translation

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
    /// text に単語のハイライトとリンク（ReadingLink）を付ける。highlights の位置は text に対するもの。
    /// ハイライトしない単語にも1語ずつリンクを付け、タップで翻訳を出せるようにする
    static func attributed(_ text: String, highlights: [ReadingHighlight], itemsByID: [UUID: VocabItem]) -> AttributedString {
        var result = AttributedString()
        for segment in ReadingSegmenter.segments(body: text, highlights: highlights) {
            if let id = segment.itemID, let item = itemsByID[id] {
                var part = AttributedString(segment.text)
                part.backgroundColor = item.state.highlightBackground
                part.link = ReadingLink.url(for: id)
                if item.state == .veryWeak {
                    part.inlinePresentationIntent = .stronglyEmphasized
                }
                result += part
                continue
            }
            for piece in ReadingSegmenter.wordPieces(segment.text) {
                var part = AttributedString(piece.text)
                if piece.isWord { part.link = ReadingLink.url(forWord: piece.text) }
                result += part
            }
        }
        return result
    }
}

extension View {
    /// VocabHighlight.attributed で付けたリンクのタップを受け取る。
    /// 覚える単語は意味のシートを、それ以外の単語は標準の翻訳（Translation）で訳したシートを出す
    func vocabTapActions(itemsByID: [UUID: VocabItem]) -> some View {
        modifier(VocabTapActions(itemsByID: itemsByID))
    }
}

private struct VocabTapActions: ViewModifier {
    let itemsByID: [UUID: VocabItem]
    @State private var selectedItem: VocabItem?
    @State private var translatingWord: TranslatingWord?

    func body(content: Content) -> some View {
        content
            .tint(.primary)
            .textSelection(.disabled)
            .environment(\.openURL, OpenURLAction { url in
                if let id = ReadingLink.itemID(from: url), let item = itemsByID[id] {
                    selectedItem = item
                } else if let word = ReadingLink.word(from: url) {
                    translatingWord = TranslatingWord(text: word)
                }
                return .handled
            })
            .sheet(item: $selectedItem) { item in
                ItemDetailSheet(item: item)
                    .presentationDetents([.height(240)])
            }
            .sheet(item: $translatingWord) { word in
                WordTranslationSheet(word: word.text)
                    .presentationDetents([.height(200)])
            }
    }
}

private struct TranslatingWord: Identifiable {
    let id = UUID()
    let text: String
}

/// 覚える単語以外をタップしたときに、標準の翻訳（Translation）で訳した結果を出すシート。
/// 言語データのダウンロード確認などシステムの画面はこのシートの上に出るよう、translationTask をここに付ける
private struct WordTranslationSheet: View {
    enum Result: Equatable {
        case translating
        case translated(String)
        case failed
    }

    let word: String
    @State private var result = Result.translating
    @State private var speaker = WordSpeaker()
    /// 単語1つでは言語を自動判定できないことがあるので、英語→日本語を指定する
    @State private var configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "en"), target: Locale.Language(identifier: "ja")
    )

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(word).font(.title2.bold())
                Spacer()
                Button {
                    speaker.speak(word)
                } label: {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.title3)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.circle)
                .accessibilityLabel("\(word) を読み上げる")
            }
            switch result {
            case .translating:
                ProgressView("翻訳中…")
            case .translated(let text):
                Text(text).font(.body)
            case .failed:
                Text("翻訳できませんでした").font(.body).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .translationTask(configuration) { session in
            do {
                result = .translated(try await session.translate(word).targetText)
            } catch {
                result = .failed
            }
        }
        .onDisappear { speaker.stop() }
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
