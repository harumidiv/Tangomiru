import SwiftUI

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
                    } else {
                        QuizResultView(session: session) { dismiss() }
                    }
                } else {
                    ProgressView()
                }
            }
            .toolbar {
                if session?.isFinished != true {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("閉じる") {
                            commit()
                            dismiss()
                        }
                    }
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
        ScrollView {
            VStack(spacing: 20) {
                HStack {
                    Text("\(session.position + 1) / \(session.totalCount)")
                    if question.isRetry {
                        Text("もう一度").bold().foregroundStyle(.orange)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(question.card.term)
                    .font(.largeTitle.bold())
                    .multilineTextAlignment(.center)

                Text(ContextHighlighter.attributed(sentence: question.card.contextSentence, highlight: question.card.highlight))
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                VStack(spacing: 12) {
                    ForEach(question.choices, id: \.self) { choice in
                        Button {
                            answer(choice)
                        } label: {
                            Text(choice)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding()
                                .background(background(for: choice, question: question), in: .rect(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)
                        .disabled(feedback != nil)
                    }
                }

                if let feedback {
                    Text(feedback.isCorrect ? "正解！" : "不正解… 正解は「\(feedback.correctAnswer)」")
                        .font(.headline)
                        .foregroundStyle(feedback.isCorrect ? .green : .red)
                    Button("次へ", action: next)
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
    }

    private func background(for choice: String, question: QuizQuestion) -> Color {
        guard feedback != nil else { return Self.neutralBackground }
        if choice == question.card.meaning { return .green.opacity(0.25) }
        if choice == selectedChoice { return .red.opacity(0.25) }
        return Self.neutralBackground
    }

    private static let neutralBackground = Color.secondary.opacity(0.12)

    private func answer(_ choice: String) {
        guard feedback == nil else { return }
        selectedChoice = choice
        feedback = session?.answer(choice)
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
