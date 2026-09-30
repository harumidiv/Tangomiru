import SwiftUI
import UIKit

/// クイズ系の画面で共通の配色。
/// ダークでは濃いグレーの背景に少し明るいカード、ライトでは薄いグレーの背景に白いカード
enum QuizPalette {
    static let background = Color(uiColor: .secondarySystemBackground)
    static let surface = Color(uiColor: .tertiarySystemBackground)
    static let border = Color(uiColor: .separator)
}

struct CircleButton: View {
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline.weight(.bold))
                .foregroundStyle(.secondary)
                .frame(width: 64, height: 64)
                .background(Circle().fill(QuizPalette.surface))
                .overlay(Circle().stroke(QuizPalette.border, lineWidth: 2))
        }
        .buttonStyle(.plain)
    }
}

struct ChoiceButton: View {
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
        case .normal: QuizPalette.surface
        case .correct: .green.opacity(0.2)
        case .wrong: .red.opacity(0.2)
        }
    }

    private var stroke: Color {
        switch style {
        case .normal: QuizPalette.border
        case .correct: .green
        case .wrong: .red
        }
    }
}
