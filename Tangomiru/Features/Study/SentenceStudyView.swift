import SwiftUI
import UIKit

/// 1文ずつ英文を読み、確認問題に答えてから和訳・文の構造・文法ポイントで学ぶ（Apple Intelligence 対応端末のみ）
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
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            sentenceCard
                            studyContent
                        }
                        .padding(.bottom, 16)
                    }
                    .scrollIndicators(.hidden)
                    .task(id: model.isRevealed) {
                        guard model.isRevealed else { return }
                        // 自分の答えの ○× を少し見せてから解説までスクロールする
                        try? await Task.sleep(for: .milliseconds(800))
                        guard !Task.isCancelled else { return }
                        withAnimation { proxy.scrollTo(Self.explanationID, anchor: .top) }
                    }
                }
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

    private static let explanationID = "explanation"

    /// 確認問題を先に出し、答えたら（問題が無いときはボタンで）和訳と解説を出す
    @ViewBuilder
    private var studyContent: some View {
        switch model.currentState {
        case .loaded(let analysis):
            if let quiz = analysis.quiz {
                QuizSection(quiz: quiz, selectedIndex: model.selectedQuizIndex) { index in
                    withAnimation { model.answerQuiz(index) }
                }
            }
            if model.isRevealed {
                ExplanationSections(analysis: analysis)
                    .id(Self.explanationID)
            }
        case .failed:
            VStack(spacing: 12) {
                Text("問題と解説を作れませんでした").font(.headline)
                Button("もう一度試す", systemImage: "arrow.clockwise") { model.retry() }
                    .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
        case .loading, nil:
            ProgressView("問題を作成中…")
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
        }
    }

    @ViewBuilder
    private var bottomButton: some View {
        let isLast = model.index == model.sentences.count - 1
        let nextTitle = isLast ? "読み終える" : "次の文へ"
        switch model.currentState {
        case .loaded(let analysis) where analysis.quiz == nil && !model.isRevealed:
            primaryButton("和訳と解説を見る") { withAnimation { model.reveal() } }
        case .loaded where model.isRevealed, .failed:
            primaryButton(nextTitle) { model.next() }
        case .loaded:
            primaryButton("問題に答えると解説が出ます") {}
                .disabled(true)
        case .loading, nil:
            primaryButton(nextTitle) {}
                .disabled(true)
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

private struct QuizSection: View {
    let quiz: GrammarQuiz
    let selectedIndex: Int?
    let onAnswer: (Int) -> Void

    var body: some View {
        StudySection(title: "確認問題") {
            VStack(alignment: .leading, spacing: 12) {
                Text(quiz.question).font(.body.weight(.semibold))
                ForEach(Array(quiz.choices.enumerated()), id: \.offset) { index, choice in
                    ChoiceButton(number: index + 1, text: choice, style: style(for: index)) {
                        onAnswer(index)
                    }
                    .allowsHitTesting(selectedIndex == nil)
                }
            }
        }
    }

    private func style(for index: Int) -> ChoiceButton.Style {
        guard let selectedIndex else { return .normal }
        if index == quiz.answerIndex { return .correct }
        if index == selectedIndex { return .wrong }
        return .normal
    }
}

private struct ExplanationSections: View {
    let analysis: SentenceAnalysis

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            StudySection(title: "和訳") {
                Text(analysis.translation).font(.body)
            }
            if !analysis.parts.isEmpty {
                StudySection(title: "文の構造") {
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
                StudySection(title: "文法ポイント") {
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
        }
        .transition(.opacity)
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
