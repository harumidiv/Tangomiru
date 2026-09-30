import SwiftUI
import UIKit

/// 1文ずつ英文を読み、和訳と解説で学ぶ（Apple Intelligence 対応端末のみ）
struct SentenceStudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: SentenceStudyModel

    /// 保存済みの解説はそのまま使い、初めて開いた文だけ作って保存する
    init(passage: Passage) {
        self.init(model: SentenceStudyModel(
            sentences: SentenceSplitter.sentences(in: passage.body),
            saved: passage.sentenceAnalyses,
            analyzer: FoundationModelsSentenceAnalyzer(),
            onAnalyzed: { sentence, analysis in passage.saveSentenceAnalysis(analysis, for: sentence) }
        ))
    }

    /// プレビューなどで解説の作り方を差し替えるため
    init(model: SentenceStudyModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        VStack(spacing: 16) {
            header
            if model.sentences.isEmpty {
                Spacer()
                ContentUnavailableView("読める文がありません", systemImage: "text.alignleft")
                Spacer()
            } else if model.isFinished {
                Spacer()
                ContentUnavailableView(
                    "おつかれさまでした", systemImage: "checkmark.circle",
                    description: Text("\(model.sentences.count)文を読み終えました")
                )
                Spacer()
                primaryButton("閉じる") { dismiss() }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        sentenceCard
                        if model.isRevealed { explanation }
                    }
                    .padding(.bottom, 16)
                }
                .scrollIndicators(.hidden)
                bottomButton
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(QuizPalette.background.ignoresSafeArea())
        .task { model.start() }
        .onDisappear { model.cancelAll() }
    }

    private var header: some View {
        HStack(spacing: 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(QuizPalette.surface))
                    .overlay(Circle().stroke(QuizPalette.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
            ProgressView(value: Double(min(model.index, model.sentences.count)), total: Double(max(model.sentences.count, 1)))
                .tint(.orange)
            Text("\(min(model.index + 1, model.sentences.count)) / \(model.sentences.count)")
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.secondary)
        }
        .padding(.top, 8)
    }

    private var sentenceCard: some View {
        Text(model.currentSentence ?? "")
            .font(.title2.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .leading)
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 20).fill(QuizPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(QuizPalette.border, lineWidth: 2))
    }

    @ViewBuilder
    private var explanation: some View {
        switch model.currentState {
        case .loaded(let analysis):
            VStack(alignment: .leading, spacing: 16) {
                StudySection(title: "和訳") {
                    Text(analysis.translation).font(.body)
                }
                if !analysis.explanation.isEmpty {
                    StudySection(title: "解説") {
                        Text(analysis.explanation).font(.body)
                    }
                }
            }
            .transition(.opacity)
        case .failed:
            VStack(spacing: 12) {
                Text("解説を作れませんでした").font(.headline)
                Button("もう一度試す", systemImage: "arrow.clockwise") { model.retry() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .loading, nil:
            ProgressView("解説を作成中…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        if model.isRevealed {
            let isLast = model.index == model.sentences.count - 1
            primaryButton(isLast ? "読み終える" : "次の文へ") { model.next() }
        } else {
            primaryButton("和訳と解説を見る") { withAnimation { model.reveal() } }
        }
    }

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .frame(maxWidth: .infinity, minHeight: 56)
        }
        .buttonStyle(.borderedProminent)
        .buttonBorderShape(.capsule)
        .tint(.orange)
    }
}

private struct StudySection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundStyle(.secondary)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(QuizPalette.surface))
    }
}
