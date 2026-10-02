import SwiftData
import SwiftUI

/// 英語のニュース・学習サイトの一覧。自分で追加したサイト（マイサイト）とおすすめのサイトを並べ、タップで外部ブラウザで開く
struct EnglishSourcesView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \CustomSource.createdAt) private var customSources: [CustomSource]
    @State private var isAddingSource = false

    var body: some View {
        List {
            Section {
                Label("気になる記事の本文をコピーして、「英文を追加」に貼り付けてください", systemImage: "doc.on.clipboard")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Section("マイサイト") {
                if customSources.isEmpty {
                    // 登録済みのリンクと見分けがつくよう、青ではなくグレーで出す
                    Button("よく使うサイトを追加", systemImage: "plus") { isAddingSource = true }
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(customSources) { source in
                        SourceRow(name: source.name, summary: source.url.host() ?? source.url.absoluteString, url: source.url)
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(customSources[index]) }
                    }
                }
            }
            ForEach(EnglishSource.Category.allCases, id: \.self) { category in
                Section(category.title) {
                    ForEach(EnglishSource.defaults(in: category)) { source in
                        SourceRow(name: source.name, summary: source.summary, url: source.url)
                    }
                }
            }
        }
        .navigationTitle("英文を探す")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("サイトを追加", systemImage: "plus") { isAddingSource = true }
            }
        }
        .sheet(isPresented: $isAddingSource) {
            AddCustomSourceView()
        }
    }
}

private struct SourceRow: View {
    let name: String
    let summary: String
    let url: URL

    var body: some View {
        Link(destination: url) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(name).font(.headline).foregroundStyle(.primary)
                    Text(summary).font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "arrow.up.right.square").foregroundStyle(.tint)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// マイサイトにサイトを追加する
private struct AddCustomSourceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var urlText = ""

    private var url: URL? { CustomSource.normalizedURL(from: urlText) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    // 文字列リテラルだと URL がリンクとして青く表示されるので、verbatim の見本にする
                    TextField("URL", text: $urlText, prompt: Text(verbatim: "https://example.com"))
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("URL")
                } footer: {
                    if !urlText.isEmpty && url == nil {
                        Text("URL の形式が正しくありません").foregroundStyle(.red)
                    }
                }
                Section("サイト名（省略可）") {
                    TextField(url?.host() ?? "例: 好きなブログ", text: $name)
                }
            }
            .navigationTitle("サイトを追加")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存", action: save).disabled(url == nil)
                }
            }
        }
    }

    private func save() {
        guard let url else { return }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        modelContext.insert(CustomSource(name: trimmed.isEmpty ? (url.host() ?? url.absoluteString) : trimmed, url: url))
        dismiss()
    }
}
