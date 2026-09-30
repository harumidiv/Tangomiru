import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Passage.createdAt, order: .reverse) private var passages: [Passage]
    @Environment(AppServices.self) private var services
    @State private var isAddingPassage = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(passages) { passage in
                    NavigationLink(value: passage) {
                        PassageRow(passage: passage)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { modelContext.delete(passages[index]) }
                }
            }
            .overlay {
                if passages.isEmpty {
                    ContentUnavailableView(
                        "英文がありません", systemImage: "text.book.closed",
                        description: Text("右上の＋から英文を貼り付けて始めましょう")
                    )
                }
            }
            .navigationTitle("Tangomiru")
            .navigationDestination(for: Passage.self) { passage in
                PassageDetailView(passage: passage)
            }
            .toolbar {
                if !passages.isEmpty {
                    ToolbarItem(placement: .topBarLeading) {
                        EditButton()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("英文を追加", systemImage: "plus") { isAddingPassage = true }
                }
            }
            .sheet(isPresented: $isAddingPassage) {
                PassageInputView()
            }
            .task(id: services.status.isReady) {
                if services.status.isReady { services.migrateMeanings(of: passages) }
            }
        }
    }
}

struct PassageRow: View {
    let passage: Passage

    var body: some View {
        let stats = passage.stats
        VStack(alignment: .leading, spacing: 6) {
            Text(passage.title).font(.headline).lineLimit(1)
            ProgressView(value: stats.masteredRate)
            HStack {
                Text("習得率 \(stats.percentText)")
                Spacer()
                if let date = passage.lastStudiedAt {
                    Text("最終学習 \(date.formatted(date: .abbreviated, time: .omitted))")
                } else {
                    Text("未学習")
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
