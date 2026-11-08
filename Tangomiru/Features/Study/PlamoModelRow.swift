import SwiftUI

/// 和訳モデル（PLaMo）のダウンロード・進み具合・削除を表示するリストの行
struct PlamoModelRow: View {
    let store: PlamoModelStore
    /// ダウンロード済みのときに、状態と削除ボタンを出すか
    var showsWhenReady = false
    @State private var isConfirmingDownload = false
    @State private var isConfirmingDelete = false

    var body: some View {
        content
            .confirmationDialog("和訳モデルをダウンロードしますか？", isPresented: $isConfirmingDownload, titleVisibility: .visible) {
                Button("ダウンロード（\(store.sizeText)）") { store.download() }
            } message: {
                Text("\(store.sizeText)のデータを Hugging Face からダウンロードします。Wi-Fi への接続をおすすめします。")
            }
            .confirmationDialog("和訳モデルを削除しますか？", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("削除", role: .destructive) { store.delete() }
            } message: {
                Text("\(store.sizeText)の空きができます。使うときはもう一度ダウンロードしてください。")
            }
    }

    @ViewBuilder
    private var content: some View {
        switch store.state {
        case .notDownloaded:
            downloadButton("和訳モデルをダウンロード（\(store.sizeText)）")
        case .downloading(let progress):
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("和訳モデルをダウンロード中… \(Int(progress * 100))%").font(.subheadline)
                    ProgressView(value: progress)
                }
                Button("キャンセル", systemImage: "xmark.circle.fill") { store.cancel() }
                    .labelStyle(.iconOnly)
                    .foregroundStyle(.secondary)
                    .buttonStyle(.plain)
            }
        case .verifying:
            HStack(spacing: 12) {
                ProgressView()
                Text("ダウンロードしたファイルを確認中…").font(.subheadline)
            }
        case .failed(let message):
            VStack(alignment: .leading, spacing: 8) {
                Text(message).font(.subheadline).foregroundStyle(.red)
                downloadButton("もう一度ダウンロード")
            }
        case .ready:
            if showsWhenReady {
                LabeledContent("和訳モデル（PLaMo）", value: "ダウンロード済み")
                Button("和訳モデルを削除", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
            }
        }
    }

    private func downloadButton(_ title: String) -> some View {
        Button(title, systemImage: "arrow.down.circle") { isConfirmingDownload = true }
    }
}
