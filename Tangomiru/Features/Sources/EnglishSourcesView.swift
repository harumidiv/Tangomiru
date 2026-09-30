import SwiftUI

/// 英語のニュース・学習サイトの一覧。タップすると外部ブラウザで開く
struct EnglishSourcesView: View {
    var body: some View {
        List {
            Section {
                Label("気になる記事の本文をコピーして、「英文を追加」に貼り付けてください", systemImage: "doc.on.clipboard")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            ForEach(EnglishSource.Category.allCases, id: \.self) { category in
                Section(category.title) {
                    ForEach(EnglishSource.defaults(in: category)) { source in
                        Link(destination: source.url) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(source.name).font(.headline).foregroundStyle(.primary)
                                    Text(source.summary).font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.up.right.square").foregroundStyle(.tint)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .navigationTitle("英文を探す")
        .navigationBarTitleDisplayMode(.inline)
    }
}
