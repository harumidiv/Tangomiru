import SwiftUI
import UIKit

/// 読解モードで本文を読んだあとに解く内容理解クイズ（Apple Intelligence 対応端末のみ）
struct ComprehensionQuizView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ComprehensionQuizModel
    private let sentences: [String]
    @State private var soundPlayer = QuizSoundPlayer()

    /// 抽出時に保存した問題があればそれを出し、無ければその場で作って保存する
    init(passage: Passage) {
        self.init(model: ComprehensionQuizModel(
            passage: passage.body,
            preloaded: passage.comprehensionQuestions,
            generator: FoundationModelsComprehensionGenerator(),
            onGenerated: { questions in passage.setComprehensionQuestions(questions) }
        ))
    }

    /// プレビューなどで問題の作り方を差し替えるため
    init(model: ComprehensionQuizModel) {
        _model = State(initialValue: model)
        sentences = SentenceSplitter.sentences(in: model.passage)
    }

    var body: some View {
        NavigationStack {
            content
                .toolbar(model.isFinished ? .visible : .hidden, for: .navigationBar)
        }
        .task { model.start() }
        .onDisappear { model.cancel() }
        // 正解は成功、不正解は失敗の振動
        .sensoryFeedback(trigger: model.selectedIndex) { _, _ in
            model.isCurrentCorrect.map { $0 ? .success : .error }
        }
        .onChange(of: model.selectedIndex) { _, _ in
            if let isCorrect = model.isCurrentCorrect { soundPlayer.play(correct: isCorrect) }
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
        }
        .padding(.top, 8)
    }

    /// 本文を上に、問題と選択肢を下に並べ、問題を読んでから本文を読み直せるようにする
    private func questionView(_ question: ComprehensionQuestion) -> some View {
        VStack(spacing: 12) {
            passagePane(highlighting: model.selectedIndex == nil
                        ? nil
                        : EvidenceLocator.sentenceIndex(of: question.evidence, in: sentences))

            VStack(alignment: .leading, spacing: 4) {
                Text("\(model.index + 1) / \(model.totalCount)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(question.question)
                    .font(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
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

    /// 本文（文ごと）。解答後は根拠の文をハイライトして、その文までスクロールする
    private func passagePane(highlighting highlighted: Int?) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(sentences.enumerated()), id: \.offset) { index, sentence in
                        Text(sentence)
                            .font(.body)
                            .lineSpacing(4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(index == highlighted ? Color.green.opacity(0.25) : Color.clear)
                            )
                            .id(index)
                    }
                }
                .padding(16)
            }
            .frame(maxHeight: .infinity)
            .background(RoundedRectangle(cornerRadius: 20).fill(QuizPalette.surface))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(QuizPalette.border, lineWidth: 2))
            .onChange(of: highlighted) { _, highlighted in
                guard let highlighted else { return }
                withAnimation { proxy.scrollTo(highlighted, anchor: .center) }
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
