import SwiftUI
import UIKit

/// 読解モードで本文を読んだあとに解く内容理解クイズ（Apple Intelligence 対応端末のみ）
struct ComprehensionQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ComprehensionQuizModel
    @State private var isPassagePresented = false

    init(passage: String) {
        self.init(model: ComprehensionQuizModel(passage: passage, generator: FoundationModelsComprehensionGenerator()))
    }

    /// プレビューなどで問題の作り方を差し替えるため
    init(model: ComprehensionQuizModel) {
        _model = State(initialValue: model)
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(model.isFinished ? .visible : .hidden, for: .navigationBar)
        }
        .task { model.start() }
        .onDisappear { model.cancel() }
        .sheet(isPresented: $isPassagePresented) {
            PassageSheet(passage: model.passage)
                .presentationDetents([.medium, .large])
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.isFinished {
            ComprehensionResultView(model: model) { dismiss() }
        } else {
            VStack(spacing: 16) {
                header
                if let question = model.current {
                    questionView(question)
                } else if model.hasFailed {
                    Spacer()
                    VStack(spacing: 12) {
                        Text("問題を作れませんでした").font(.headline)
                        Button("もう一度試す", systemImage: "arrow.clockwise") { model.retry() }
                            .buttonStyle(.bordered)
                    }
                    Spacer()
                } else {
                    Spacer()
                    ProgressView("問題を作成中…")
                    Spacer()
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 8)
            .background(QuizPalette.background.ignoresSafeArea())
        }
    }

    private var header: some View {
        HStack(spacing: 16) {
            roundButton(systemImage: "xmark", label: "閉じる") { dismiss() }
            ProgressView(value: Double(model.index), total: Double(max(model.totalCount, 1)))
                .tint(.orange)
            roundButton(systemImage: "doc.text", label: "本文を見る") { isPassagePresented = true }
        }
        .padding(.top, 8)
    }

    private func questionView(_ question: ComprehensionQuestion) -> some View {
        VStack(spacing: 16) {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("\(model.index + 1) / \(model.totalCount)")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text(question.question)
                        .font(.title3.weight(.semibold))
                    if model.selectedIndex != nil, let evidence = question.evidence {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("根拠").font(.caption.bold()).foregroundStyle(.secondary)
                            Text(evidence).font(.callout).italic()
                        }
                        .padding(.top, 8)
                        .transition(.opacity)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
            }
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 20).fill(QuizPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(QuizPalette.border, lineWidth: 2))

            VStack(spacing: 12) {
                ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                    ChoiceButton(number: index + 1, text: choice, style: style(for: index, question: question)) {
                        withAnimation { model.answer(index) }
                    }
                    .allowsHitTesting(model.selectedIndex == nil)
                }
            }

            if model.selectedIndex != nil {
                Button {
                    model.next()
                } label: {
                    Text(model.index + 1 >= model.totalCount ? "結果を見る" : "次へ")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 52)
                }
                .buttonStyle(.borderedProminent)
                .buttonBorderShape(.capsule)
                .tint(.orange)
            }
        }
    }

    private func style(for index: Int, question: ComprehensionQuestion) -> ChoiceButton.Style {
        guard let selectedIndex = model.selectedIndex else { return .normal }
        if index == question.answerIndex { return .correct }
        if index == selectedIndex { return .wrong }
        return .normal
    }

    private func roundButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title3.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, height: 48)
                .background(Circle().fill(QuizPalette.surface))
                .overlay(Circle().stroke(QuizPalette.border, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

private struct ComprehensionResultView: View {
    let model: ComprehensionQuizModel
    let onClose: () -> Void

    var body: some View {
        List {
            Section {
                Text("\(model.correctCount) / \(model.questions.count) 問正解")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            if !model.wrongQuestions.isEmpty {
                Section("間違えた問題") {
                    ForEach(Array(model.wrongQuestions.enumerated()), id: \.offset) { _, question in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(question.question).font(.headline)
                            Text("正解: \(question.choices[question.answerIndex])")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                            if let evidence = question.evidence {
                                Text(evidence).font(.callout).italic().foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
        }
        .navigationTitle("内容理解の結果")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了", action: onClose)
            }
        }
    }
}

private struct PassageSheet: View {
    let passage: String

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(passage)
                    .font(.body)
                    .lineSpacing(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .navigationTitle("本文")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
