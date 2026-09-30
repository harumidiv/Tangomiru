import SwiftData
import SwiftUI

struct ItemListView: View {
    let passage: Passage

    var body: some View {
        List(passage.sortedItems) { item in
            ItemToggleRow(item: item)
        }
        .navigationTitle("単語一覧")
    }
}

private struct ItemToggleRow: View {
    @Bindable var item: VocabItem

    var body: some View {
        Toggle(isOn: $item.isEnabled) {
            VocabLabel(term: item.term, meaning: item.meaning, state: item.state)
        }
    }
}
