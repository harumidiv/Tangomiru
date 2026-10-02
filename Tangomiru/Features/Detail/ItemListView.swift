import SwiftData
import SwiftUI

struct ItemListView: View {
    let passage: Passage
    @State private var reader = WordListReader()
    @State private var speaker = WordSpeaker()

    /// まとめて読み上げる語（出題ON の語を一覧の順に）
    private var enabledItems: [VocabItem] { passage.sortedItems.filter(\.isEnabled) }

    private var readingItemID: PersistentIdentifier? {
        guard let index = reader.currentIndex, enabledItems.indices.contains(index) else { return nil }
        return enabledItems[index].persistentModelID
    }

    var body: some View {
        ScrollViewReader { proxy in
            List(passage.sortedItems) { item in
                ItemToggleRow(item: item, isReading: item.persistentModelID == readingItemID) {
                    reader.stop()
                    speaker.speak(item.term)
                }
                .id(item.persistentModelID)
            }
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
    let onSpeak: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onSpeak) {
                Image(systemName: "speaker.wave.2")
                    .font(.body)
                    .frame(width: 32, height: 32)
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("\(item.term) を読み上げる")
            Toggle(isOn: $item.isEnabled) {
                VocabLabel(term: item.term, meaning: item.meaning, state: item.state)
            }
        }
        .listRowBackground(isReading ? Color.orange.opacity(0.18) : nil)
    }
}
