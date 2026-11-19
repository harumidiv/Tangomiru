import SwiftData
import SwiftUI

struct ItemListView: View {
    let passage: Passage
    @State private var reader = WordListReader()
    @State private var speaker = WordSpeaker()
    /// 単語一覧を開くたびに、どちらも隠さない状態から始める
    @State private var hidesTerm = false
    @State private var hidesMeaning = false

    /// まとめて読み上げる語（出題ON の語を一覧の順に）
    private var enabledItems: [VocabItem] { passage.sortedItems.filter(\.isEnabled) }

    private var readingItemID: PersistentIdentifier? {
        guard let index = reader.currentIndex, enabledItems.indices.contains(index) else { return nil }
        return enabledItems[index].persistentModelID
    }

    private var hideOptions: some View {
        HStack(spacing: 24) {
            CheckBox(title: "英語を隠す", isOn: $hidesTerm)
            CheckBox(title: "和訳を隠す", isOn: $hidesMeaning)
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(passage.sortedItems) { item in
                ItemToggleRow(
                    item: item, isReading: item.persistentModelID == readingItemID,
                    hidesTerm: hidesTerm, hidesMeaning: hidesMeaning
                ) {
                    reader.stop()
                    speaker.speak(item.term)
                }
                .id(item.persistentModelID)
            }
            // 下の方までスクロールしても切り替えられるよう、一覧の上に固定する
            .safeAreaInset(edge: .top, spacing: 0) { hideOptions }
            .onChange(of: readingItemID) { _, id in
                guard let id else { return }
                withAnimation { proxy.scrollTo(id, anchor: .center) }
            }
        }
        .navigationTitle("単語一覧")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Group {
                    if reader.isReading {
                        Button("停止", systemImage: "stop.fill") { reader.stop() }
                    } else {
                        Button("まとめて読み上げ", systemImage: "speaker.wave.2.fill") {
                            speaker.stop()
                            reader.read(enabledItems.map(\.term))
                        }
                        .disabled(enabledItems.isEmpty)
                    }
                }
                .labelStyle(.titleAndIcon)
            }
        }
        .onDisappear {
            reader.stop()
            speaker.stop()
        }
    }
}

private struct ItemToggleRow: View {
    @Bindable var item: VocabItem
    let isReading: Bool
    let hidesTerm: Bool
    let hidesMeaning: Bool
    let onSpeak: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSpeak) {
                Image(systemName: "speaker.wave.2")
                    .font(.body)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            // 英語を隠しているときは、読み上げ機能のラベルからも語がわからないようにする
            .accessibilityLabel(hidesTerm ? "英語を読み上げる" : "\(item.term) を読み上げる")
            Toggle(isOn: $item.isEnabled) {
                VocabLabel(
                    term: item.term, meaning: item.meaning, state: item.state,
                    hidesTerm: hidesTerm, hidesMeaning: hidesMeaning
                )
            }
        }
        .listRowBackground(isReading ? Color.orange.opacity(0.18) : nil)
    }
}

/// チェックボックス風のトグル
private struct CheckBox: View {
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Label(title, systemImage: isOn ? "checkmark.square.fill" : "square")
                .foregroundStyle(isOn ? Color.orange : Color.primary)
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
