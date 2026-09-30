import SwiftUI
import UIKit

struct QuizView: View {
    @Environment(AppServices.self) private var services
    @Environment(\.dismiss) private var dismiss
    let passage: Passage
    let length: QuizLength
    @State private var session: QuizSession?
    @State private var feedback: AnswerFeedback?
    @State private var selectedChoice: String?
    @State private var isCommitted = false

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    if let question = session.current {
                        questionView(question, session: session)
                            .toolbar(.hidden, for: .navigationBar)
                    } else {
                        QuizResultView(session: session) { dismiss() }
                    }
                } else {
                    ProgressView()
                }
            }
        }
        .task {
            guard session == nil else { return }
            session = QuizSession(
                cards: passage.quizCards, length: length, fallbackMeanings: services.fallbackMeanings()
            )
            if session?.isFinished == true { commit() }
        }
    }

    private func questionView(_ question: QuizQuestion, session: QuizSession) -> some View {
        VStack(spacing: 16) {
            header(progress: session.progress)
            card(question, session: session)
            HStack {
                Spacer()
                if feedback == nil {
                    CircleButton(title: "SKIP", action: skip)
                } else {
                    CircleButton(title: "次へ", isProminent: true, action: next)
                }
            }
            VStack(spacing: 12) {
                ForEach(Array(question.choices.enumerated()), id: \.element) { index, choice in
                    ChoiceButton(
                        number: index + 1,
                        text: choice,
                        style: style(for: choice, question: question)
                    ) {
                        answer(choice)
                    }
                    .allowsHitTesting(feedback == nil)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.bottom, 8)
        .background(Self.background.ignoresSafeArea())
    }

    private func header(progress: Double) -> some View {
        HStack(spacing: 16) {
            Button {
                commit()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 48, height: 48)
                    .background(Circle().fill(Self.surface))
                    .overlay(Circle().stroke(Self.border, lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("閉じる")
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(uiColor: .systemGray4))
                    Capsule().fill(.orange)
                        .frame(width: geometry.size.width * progress)
                }
            }
            .frame(height: 10)
            .animation(.easeOut, value: progress)
        }
        .padding(.top, 8)
    }

    /// 英単語は常にカードの中心。問題番号は単語のすぐ上、解答後の例文はカード下部に重ねて表示し、単語の位置を動かさない
    private func card(_ question: QuizQuestion, session: QuizSession) -> some View {
        ZStack {
            Text(question.card.term)
                .font(.system(size: 44, weight: .bold))
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.5)
                .lineLimit(2)
                .overlay(alignment: .top) {
                    VStack(spacing: 4) {
                        Text("\(session.position + 1) / \(session.totalCount)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                        if question.isRetry {
                            Text("もう一度").font(.caption.bold()).foregroundStyle(.orange)
                        }
                    }
                    .fixedSize()
                    .alignmentGuide(.top) { $0[.bottom] + 12 }
                }
            if let feedback {
                VStack(spacing: 8) {
                    Spacer()
                    Text(feedback.isCorrect ? "正解！" : "正解は「\(feedback.correctAnswer)」")
                        .font(.headline)
                        .foregroundStyle(feedback.isCorrect ? .green : .red)
                    Text(ContextHighlighter.attributed(sentence: question.card.contextSentence, highlight: question.card.highlight))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                }
                .transition(.opacity)
            }
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(RoundedRectangle(cornerRadius: 20).fill(Self.surface))
        .overlay(RoundedRectangle(cornerRadius: 20).stroke(Self.border, lineWidth: 2))
    }

    private func style(for choice: String, question: QuizQuestion) -> ChoiceButton.Style {
        guard feedback != nil else { return .normal }
        if choice == question.card.meaning { return .correct }
        if choice == selectedChoice { return .wrong }
        return .normal
    }

    // ダークでは濃いグレーの背景に少し明るいカード、ライトでは薄いグレーの背景に白いカード
    fileprivate static let background = Color(uiColor: .secondarySystemBackground)
    fileprivate static let surface = Color(uiColor: .tertiarySystemBackground)
    fileprivate static let border = Color(uiColor: .separator)

    private func answer(_ choice: String) {
        guard feedback == nil else { return }
        selectedChoice = choice
        withAnimation { feedback = session?.answer(choice) }
    }

    private func skip() {
        guard feedback == nil else { return }
        selectedChoice = nil
        withAnimation { feedback = session?.skip() }
    }

    private func next() {
        session?.advance()
        feedback = nil
        selectedChoice = nil
        if session?.isFinished == true { commit() }
    }

    /// 解答済みの分のスコアを保存する（途中で閉じた場合も反映）
    private func commit() {
        guard !isCommitted, let session, !session.changes.isEmpty else { return }
        passage.applyQuizResult(session.changes)
        isCommitted = true
    }
}

private struct CircleButton: View {
    let title: String
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(isProminent ? Color.white : Color.secondary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(isProminent ? Color.orange : QuizView.surface))
                .overlay(Circle().stroke(QuizView.border, lineWidth: isProminent ? 0 : 2))
        }
        .buttonStyle(.plain)
    }
}

private struct ChoiceButton: View {
    enum Style {
        case normal
        case correct
        case wrong
    }

    let number: Int
    let text: String
    let style: Style
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 20) {
                Text("\(number)")
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.tertiary)
                Text(text)
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 28)
            .frame(maxWidth: .infinity, minHeight: 64)
            .background(Capsule().fill(fill))
            .overlay(Capsule().stroke(stroke, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }

    private var fill: Color {
        switch style {
        case .normal: QuizView.surface
        case .correct: .green.opacity(0.2)
        case .wrong: .red.opacity(0.2)
        }
    }

    private var stroke: Color {
        switch style {
        case .normal: QuizView.border
        case .correct: .green
        case .wrong: .red
        }
    }
}
