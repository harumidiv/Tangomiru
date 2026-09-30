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
    /// 制限時間の残り割合（1 → 0）
    @State private var remaining = 1.0
    /// 復習の回を始めるたびに増やし、タイマーを確実にリセットする
    @State private var round = 0

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    if let question = session.current {
                        questionView(question, session: session)
                            .toolbar(.hidden, for: .navigationBar)
                            .task(id: "\(round)-\(session.position)") { await runCountdown() }
                            .task(id: feedback) { await advanceAfterReveal() }
                    } else {
                        QuizResultView(session: session, onReview: startReview) { dismiss() }
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
            header(remaining: remaining)
            card(question, session: session)
            HStack {
                Spacer()
                CircleButton(title: "SKIP", action: skip)
                    .opacity(feedback == nil ? 1 : 0.4)
                    .allowsHitTesting(feedback == nil)
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

    /// 上部のメーターは制限時間の残り（10秒で空になる）
    private func header(remaining: Double) -> some View {
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
                    Capsule().fill(remaining > 0.3 ? Color.orange : Color.red)
                        .frame(width: geometry.size.width * remaining)
                }
            }
            .frame(height: 10)
            .accessibilityLabel("残り時間")
            .accessibilityValue("\(Int((remaining * 10).rounded(.up)))秒")
        }
        .padding(.top, 8)
    }

    /// 英単語は常にカードの中心。問題番号は単語のすぐ上に重ねて表示し、単語の位置を動かさない
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
                        if session.isReview {
                            Text("復習").font(.caption.bold()).foregroundStyle(.orange)
                        }
                    }
                    .fixedSize()
                    .alignmentGuide(.top) { $0[.bottom] + 12 }
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

    /// 10秒たっても解答がなければ不正解として扱う
    private func runCountdown() async {
        let start = ContinuousClock.now
        remaining = 1
        while !Task.isCancelled && feedback == nil {
            remaining = QuizCountdown.remainingFraction(elapsed: ContinuousClock.now - start)
            if remaining <= 0 {
                selectedChoice = nil
                withAnimation { feedback = session?.skip() }
                return
            }
            try? await Task.sleep(for: .milliseconds(50))
        }
    }

    /// ○×を少し見せてから自動で次の問題へ進む
    private func advanceAfterReveal() async {
        guard feedback != nil else { return }
        try? await Task.sleep(for: QuizCountdown.revealDuration)
        guard !Task.isCancelled else { return }
        next()
    }

    /// 間違えた語だけで復習の回を始める（スコアは変えない）
    private func startReview() {
        guard let finished = session, !finished.wrongCards.isEmpty else { return }
        commit()
        feedback = nil
        selectedChoice = nil
        round += 1
        session = QuizSession(
            reviewing: finished.wrongCards,
            passageMeanings: passage.items.map(\.meaning),
            fallbackMeanings: services.fallbackMeanings()
        )
    }

    private func next() {
        session?.advance()
        feedback = nil
        selectedChoice = nil
        if session?.isFinished == true { commit() }
    }

    /// 解答済みの分のスコアを保存する（途中で閉じた場合も反映）
    private func commit() {
        guard !isCommitted, let session, !session.isReview, !session.changes.isEmpty else { return }
        passage.applyQuizResult(session.changes)
        isCommitted = true
    }
}

private struct CircleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(QuizView.surface))
                .overlay(Circle().stroke(QuizView.border, lineWidth: 2))
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
                marker
                    .frame(width: 34)
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

    /// 解答前は番号、解答後は正解を ○、選んだ不正解を × にする（番号は隠す）
    @ViewBuilder
    private var marker: some View {
        switch style {
        case .normal:
            Text("\(number)")
                .font(.title2.weight(.semibold))
                .foregroundStyle(.tertiary)
        case .correct:
            Image(systemName: "circle")
                .font(.title2.weight(.bold))
                .foregroundStyle(.green)
                .accessibilityLabel("正解")
        case .wrong:
            Image(systemName: "xmark")
                .font(.title2.weight(.bold))
                .foregroundStyle(.red)
                .accessibilityLabel("不正解")
        }
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
