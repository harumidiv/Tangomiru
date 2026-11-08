import SwiftUI

/// アプリについて。端末内の翻訳に使っている PLaMo の表示（Built with PLaMo）と、同梱しているソフトウェアのライセンス
struct AboutView: View {
    @Environment(AppServices.self) private var services
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Built with PLaMo").font(.headline)
                    Text("「1文ずつ学ぶ」の和訳は、株式会社Preferred Networksの翻訳モデル PLaMo 3 Translate を使い、端末内で作っています（和訳モデルのダウンロードが必要です）。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("和訳モデル") {
                PlamoModelRow(store: services.plamoModel, showsWhenReady: true)
            }

            Section("ライセンス") {
                ForEach(BundledLicense.all) { license in
                    NavigationLink(license.title) {
                        LicenseTextView(license: license)
                    }
                }
            }

            if let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String {
                Section {
                    LabeledContent("バージョン", value: version)
                }
            }
        }
        .navigationTitle("このアプリについて")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("閉じる", action: onClose)
            }
        }
    }
}

/// アプリに同梱しているライセンス本文（Resources/Licenses）
struct BundledLicense: Identifiable, Hashable {
    let title: String
    let fileName: String
    var id: String { fileName }

    static let all = [
        BundledLicense(title: "PLaMoコミュニティライセンス契約", fileName: "PLaMoCommunityLicense-ja"),
        BundledLicense(title: "PLaMo Community License Agreement", fileName: "PLaMoCommunityLicense-en"),
        BundledLicense(title: "llama.cpp (MIT License)", fileName: "llama.cpp-LICENSE"),
    ]

    var text: String? {
        let url = Bundle.main.url(forResource: fileName, withExtension: "txt")
            ?? Bundle.main.url(forResource: fileName, withExtension: "txt", subdirectory: "Licenses")
        return url.flatMap { try? String(contentsOf: $0, encoding: .utf8) }
    }
}

private struct LicenseTextView: View {
    let license: BundledLicense

    var body: some View {
        ScrollView {
            Text(license.text ?? "ライセンス本文を読み込めませんでした。")
                .font(.footnote)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
        .navigationTitle(license.title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    NavigationStack { AboutView {} }
        .environment(AppServices())
}
