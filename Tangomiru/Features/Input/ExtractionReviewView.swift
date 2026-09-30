import SwiftData
import SwiftUI

struct ExtractionReviewView: View {
    @Environment(\.modelContext) private var modelContext
    let title: String
    let passageBody: String
    let result: ExtractionResult
    let onSaved: () -> Void
    @State private var enabled: [Bool]

    init(title: String, passageBody: String, result: ExtractionResult, onSaved: @escaping () -> Void) {
        self.title = title
        self.passageBody = passageBody
        self.result = result
        self.onSaved = onSaved
        _enabled = State(initialValue: Array(repeating: true, count: result.items.count))
    }

    var body: some View {
        List {
            if !result.items.isEmpty {
                if !result.usedAI {
                    Section {
                        Label("辞書モードで抽出しました", systemImage: "book")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                Section("\(result.items.count)語を抽出（出題ON \(enabled.filter { $0 }.count)語）") {
                    ForEach(result.items.indices, id: \.self) { index in
                        Toggle(isOn: $enabled[index]) {
                            VocabLabel(term: result.items[index].term, meaning: result.items[index].meaning, state: nil)
                        }
                    }
                }
            }
        }
        .overlay {
            if result.items.isEmpty {
                ContentUnavailableView(
                    "出題できる語が見つかりませんでした", systemImage: "text.magnifyingglass",
                    description: Text("英語以外の文章や、基本語だけの文章からは語を抽出できません")
                )
            }
        }
        .navigationTitle("抽出結果")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存", action: save).disabled(result.items.isEmpty)
            }
        }
    }

    private func save() {
        let passage = Passage(title: title, body: passageBody, usedAI: result.usedAI)
        modelContext.insert(passage)
        passage.items = zip(result.items, enabled).map { VocabItem(extracted: $0, isEnabled: $1) }
        onSaved()
    }
}
