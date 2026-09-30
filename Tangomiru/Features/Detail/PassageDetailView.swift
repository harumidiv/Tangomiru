import SwiftData
import SwiftUI

struct PassageDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let passage: Passage
    @State private var isConfirmingDelete = false
    @AppStorage("quizLength") private var quizLengthRaw = QuizLength.ten.rawValue
    @State private var isQuizPresented = false
    @State private var isStudyPresented = false
    private let isSentenceStudyAvailable = FoundationModelsSentenceAnalyzer().isAvailable

    private var quizLength: Binding<QuizLength> {
        Binding(
            get: { QuizLength(rawValue: quizLengthRaw) ?? .ten },
            set: { quizLengthRaw = $0.rawValue }
        )
    }

    /// 画面を閉じてから削除する（閉じるアニメーション中に削除済みのデータを描画しないため）
    private func deletePassage() {
        let passage = passage
        let modelContext = modelContext
        dismiss()
        Task {
            try? await Task.sleep(for: .milliseconds(500))
            modelContext.delete(passage)
            try? modelContext.save()
        }
    }

    var body: some View {
        let stats = passage.stats
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text("習得率 \(stats.percentText)").font(.title2.bold())
                    ProgressView(value: stats.masteredRate)
                    HStack {
                        ForEach(MasteryState.displayOrder) { state in
                            VStack(spacing: 2) {
                                Text("\(stats.count(state))").font(.headline)
                                Text(state.label).font(.caption2)
                            }
                            .foregroundStyle(state.color)
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            Section("クイズ") {
                Picker("出題数", selection: quizLength) {
                    ForEach(QuizLength.allCases) { length in
                        Text(length.label).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                Button("クイズを始める", systemImage: "play.fill") { isQuizPresented = true }
                    .disabled(stats.total == 0)
                if stats.total == 0 {
                    Text("出題ONの語がありません").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("1文ずつ学ぶ", systemImage: "text.book.closed") { isStudyPresented = true }
                    .disabled(!isSentenceStudyAvailable)
            } footer: {
                Text(isSentenceStudyAvailable
                     ? "1文ずつ読んで、和訳・文の構造・文法ポイントを確認します"
                     : "Apple Intelligence 対応端末で使えます")
            }
            Section {
                NavigationLink {
                    ReadingView(passage: passage)
                } label: {
                    Label("読解モード", systemImage: "text.viewfinder")
                }
                NavigationLink {
                    ItemListView(passage: passage)
                } label: {
                    Label("単語一覧（\(passage.items.count)語）", systemImage: "list.bullet")
                }
            }
        }
        .navigationTitle(passage.title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu("その他", systemImage: "ellipsis") {
                    Button("この英文を削除", systemImage: "trash", role: .destructive) { isConfirmingDelete = true }
                }
            }
        }
        .confirmationDialog("「\(passage.title)」を削除しますか？", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button("削除", role: .destructive, action: deletePassage)
        } message: {
            Text("単語の学習記録も一緒に削除されます。この操作は取り消せません。")
        }
        .fullScreenCover(isPresented: $isStudyPresented) {
            SentenceStudyView(passage: passage)
        }
        .fullScreenCover(isPresented: $isQuizPresented) {
            QuizView(passage: passage, length: quizLength.wrappedValue)
        }
    }
}
