import SwiftUI
import UIKit

/// 1文ずつ英文を読み、和訳・文の構造・文法ポイント・確認クイズで学ぶ（Apple Intelligence 対応端末のみ）
struct SentenceStudyView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: SentenceStudyModel

    init(passage: Passage) {
        self.init(model: SentenceStudyModel(
            sentences: SentenceSplitter.sentences(in: passage.body),
            analyzer: FoundationModelsSentenceAnalyzer()
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
            AnalysisSections(analysis: analysis, selectedQuizIndex: model.selectedQuizIndex) { model.answerQuiz($0) }
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
        if !model.isRevealed {
            primaryButton("和訳と解説を見る") { withAnimation { model.reveal() } }
        } else {
            let isLast = model.index == model.sentences.count - 1
            let title = isWaitingForQuiz ? "クイズに答えると進めます" : (isLast ? "読み終える" : "次の文へ")
            primaryButton(title) { model.next() }
                .disabled(!canMoveOn)
        }
    }

    private var isWaitingForQuiz: Bool {
        model.currentAnalysis?.quiz != nil && model.selectedQuizIndex == nil
    }

    /// クイズがある場合は答えてから次へ進める
    private var canMoveOn: Bool {
        switch model.currentState {
        case .loaded(let analysis): analysis.quiz == nil || model.selectedQuizIndex != nil
        case .failed: true
        case .loading, nil: false
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

private struct AnalysisSections: View {
    let analysis: SentenceAnalysis
    let selectedQuizIndex: Int?
    let onAnswer: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            section("和訳") {
                Text(analysis.translation).font(.body)
            }
            if !analysis.parts.isEmpty {
                section("文の構造") {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(Array(analysis.parts.enumerated()), id: \.offset) { _, part in
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                Text(part.role)
                                    .font(.caption.bold())
                                    .foregroundStyle(.orange)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Capsule().fill(.orange.opacity(0.15)))
                                Text(part.text).font(.body)
                            }
                        }
                    }
                }
            }
            if !analysis.points.isEmpty {
                section("文法ポイント") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(analysis.points.enumerated()), id: \.offset) { _, point in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(point.title).font(.headline)
                                Text(point.explanation).font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            if let quiz = analysis.quiz {
                section("確認クイズ") {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(quiz.question).font(.body.weight(.semibold))
                        ForEach(Array(quiz.choices.enumerated()), id: \.offset) { index, choice in
                            ChoiceButton(number: index + 1, text: choice, style: style(for: index, quiz: quiz)) {
                                onAnswer(index)
                            }
                            .allowsHitTesting(selectedQuizIndex == nil)
                        }
                    }
                }
            }
        }
        .transition(.opacity)
    }

    private func style(for index: Int, quiz: GrammarQuiz) -> ChoiceButton.Style {
        guard let selectedQuizIndex else { return .normal }
        if index == quiz.answerIndex { return .correct }
        if index == selectedQuizIndex { return .wrong }
        return .normal
    }

    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline.bold()).foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16).fill(QuizPalette.surface))
    }
}
