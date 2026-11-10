import SwiftUI

struct ReadingView: View {
    let passage: Passage
    @State private var selectedItem: VocabItem?
    @State private var isComprehensionQuizPresented = false
    private let isComprehensionQuizAvailable = FoundationModelsComprehensionGenerator().isAvailable

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                legend
                Text(VocabHighlight.attributed(passage.body, highlights: passage.readingHighlights, itemsByID: itemsByID))
                    .font(.body)
                    .lineSpacing(6)
                    .onVocabTap(itemsByID: itemsByID) { selectedItem = $0 }
                comprehensionQuizEntry
            }
            .padding()
        }
        .navigationTitle("読解モード")
        .navigationBarTitleDisplayMode(.inline)
        .fullScreenCover(isPresented: $isComprehensionQuizPresented) {
            ComprehensionQuizView(passage: passage)
        }
        .sheet(item: $selectedItem) { item in
            ItemDetailSheet(item: item)
                .presentationDetents([.height(240)])
        }
    }

    /// 本文を読み終えたら内容理解クイズへ（Apple Intelligence 対応端末のみ）
    private var comprehensionQuizEntry: some View {
        VStack(spacing: 8) {
            Button {
                isComprehensionQuizPresented = true
            } label: {
                Label("内容理解クイズに挑戦", systemImage: "checkmark.bubble")
                    .font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 52)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.capsule)
            .tint(.orange)
            .disabled(!isComprehensionQuizAvailable)
            Text(isComprehensionQuizAvailable
                 ? "本文の内容を理解できたか、4択の問題で確かめます"
                 : "Apple Intelligence 対応端末で使えます")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(.top, 24)
    }

    private var legend: some View {
        HStack(spacing: 8) {
            ForEach([MasteryState.veryWeak, .weak, .vague, .unseen]) { state in
                MasteryBadge(state: state)
            }
            Spacer()
            Text("\(passage.stats.percentText) 習得").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var itemsByID: [UUID: VocabItem] { passage.itemsByID }
}
