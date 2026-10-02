import SwiftData
import SwiftUI

struct PassageDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let passage: Passage
    @State private var isConfirmingDelete = false
    @AppStorage("quizLength") private var quizLengthRaw = QuizLength.ten.rawValue
    @AppStorage("quizScope") private var quizScopeRaw = QuizScope.auto.rawValue
    @State private var isQuizPresented = false
    @State private var isStudyPresented = false
    private let isSentenceStudyAvailable = FoundationModelsSentenceAnalyzer().isAvailable

    private var quizLength: Binding<QuizLength> {
        Binding(
            get: { QuizLength(rawValue: quizLengthRaw) ?? .ten },
            set: { quizLengthRaw = $0.rawValue }
        )
    }

    /// 選んでいた範囲の語が0問ならおまかせに戻す
    private func effectiveScope(_ stats: MasteryStats) -> QuizScope {
        let scope = QuizScope(rawValue: quizScopeRaw) ?? .auto
        return scope.count(in: stats) > 0 ? scope : .auto
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
                ScopePicker(stats: stats, selection: Binding(
                    get: { effectiveScope(stats) },
                    set: { quizScopeRaw = $0.rawValue }
                ))
                .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 12, trailing: 0))
                Picker("出題数", selection: quizLength) {
                    ForEach(QuizLength.allCases) { length in
                        Text(length.label).tag(length)
                    }
                }
                .pickerStyle(.segmented)
                Button("クイズを始める", systemImage: "play.fill") { isQuizPresented = true }
                    .disabled(effectiveScope(stats).count(in: stats) == 0)
                if stats.total == 0 {
                    Text("出題ONの語がありません").font(.footnote).foregroundStyle(.secondary)
                }
            }
            Section {
                Button("1文ずつ学ぶ", systemImage: "text.book.closed") { isStudyPresented = true }
                    .disabled(!isSentenceStudyAvailable)
            } footer: {
                Text(isSentenceStudyAvailable
                     ? "1文ずつ読んで、和訳と解説を確認します"
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
            QuizView(passage: passage, length: quizLength.wrappedValue, scope: effectiveScope(passage.stats))
        }
    }
}

/// 出題範囲を横スクロールのカードで選ぶ（各カードに問題数。0問は選べない）
private struct ScopePicker: View {
    let stats: MasteryStats
    @Binding var selection: QuizScope

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 10) {
                ForEach(QuizScope.allCases) { scope in
                    let count = scope.count(in: stats)
                    Button {
                        selection = scope
                    } label: {
                        VStack(spacing: 6) {
                            icon(for: scope)
                            Text(scope.label).font(.subheadline.bold())
                            Text("\(count)問").font(.caption).foregroundStyle(.secondary)
                        }
                        .frame(width: 84, height: 88)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color(.secondarySystemGroupedBackground)))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(selection == scope ? Color.orange : Color(.separator), lineWidth: selection == scope ? 3 : 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(count == 0)
                    .opacity(count == 0 ? 0.4 : 1)
                    .accessibilityLabel("\(scope.label) \(count)問")
                    .accessibilityAddTraits(selection == scope ? .isSelected : [])
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
    }

    @ViewBuilder
    private func icon(for scope: QuizScope) -> some View {
        if let state = scope.state {
            Circle().fill(state.color).frame(width: 18, height: 18)
        } else {
            Image(systemName: "sparkles").foregroundStyle(.orange).frame(height: 18)
        }
    }
}
