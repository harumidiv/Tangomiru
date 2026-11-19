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
    /// 保存済みの訳か標準の翻訳（Translation）で得た訳をシートに表示する。
    /// passage を渡すと、シートからその英文の単語帳に語を追加できる
    func vocabTapActions(itemsByID: [UUID: VocabItem], addingTo passage: Passage? = nil) -> some View {
        modifier(VocabTapActions(itemsByID: itemsByID, passage: passage))
    }
}

private struct VocabTapActions: ViewModifier {
    let itemsByID: [UUID: VocabItem]
    let passage: Passage?
    @State private var lookup: WordLookup?

    func body(content: Content) -> some View {
        content
            .tint(.primary)
            .textSelection(.disabled)
            .environment(\.openURL, OpenURLAction { url in
                if let id = ReadingLink.itemID(from: url), let item = itemsByID[id] {
                    lookup = WordLookup(text: item.term, meaning: item.meaning)
                } else if let word = ReadingLink.word(from: url) {
                    // ハイライトしていない語でも、オフにした語や習得済みの語なら保存済みの訳を使う
                    let saved = passage?.item(matching: word)
                    lookup = WordLookup(text: word, meaning: saved?.meaning)
                }
                return .handled
            })
            .sheet(item: $lookup) { word in
                WordTranslationSheet(word: word.text, meaning: word.meaning, passage: passage)
                    .presentationDetents([.height(passage == nil ? 200 : 260)])
            }
    }
}

private struct WordLookup: Identifiable {
    let id = UUID()
    let text: String
    let meaning: String?
}

/// タップした単語と和訳を出すシート。
/// 言語データのダウンロード確認などシステムの画面はこのシートの上に出るよう、translationTask をここに付ける
private struct WordTranslationSheet: View {
    enum Result: Equatable {
        case translating
        case translated(String)
        case failed
    }

    let word: String
    let passage: Passage?
    @State private var result: Result
    @State private var speaker = WordSpeaker()
    private let configuration: TranslationSession.Configuration?

    init(word: String, meaning: String?, passage: Passage?) {
        self.word = word
        self.passage = passage
        if let meaning {
            _result = State(initialValue: .translated(meaning))
            configuration = nil
        } else {
            _result = State(initialValue: .translating)
            // 単語1つでは言語を自動判定できないことがあるので、英語→日本語を指定する
            configuration = TranslationSession.Configuration(
                source: Locale.Language(identifier: "en"), target: Locale.Language(identifier: "ja")
            )
        }
    }

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
            if passage != nil { addButton }
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

    /// 単語帳に入っていて（オンになっていて）クイズに出る語か
    private var isInWordList: Bool {
        passage?.item(matching: word)?.isEnabled == true
    }

    @ViewBuilder
    private var addButton: some View {
        if isInWordList {
            Label("単語帳に追加済み", systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 44)
        } else {
            Button {
                guard case .translated(let meaning) = result else { return }
                passage?.addWord(word, meaning: meaning)
            } label: {
                Label("単語帳に追加", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.orange)
            .disabled(!isTranslated)
        }
    }

    private var isTranslated: Bool {
        if case .translated = result { true } else { false }
    }
}
