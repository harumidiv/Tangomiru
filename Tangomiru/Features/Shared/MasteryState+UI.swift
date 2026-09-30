import SwiftUI

extension MasteryState {
    var color: Color {
        switch self {
        case .veryWeak: .red
        case .weak: .pink
        case .unseen: .gray
        case .vague: .orange
        case .mastered: .green
        }
    }

    /// 読解モードのハイライト背景（超苦手=濃い赤、苦手=赤系、うろ覚え=黄系、未学習=グレー系）
    var highlightBackground: Color {
        switch self {
        case .veryWeak: .red.opacity(0.4)
        case .weak: .red.opacity(0.18)
        case .unseen: .gray.opacity(0.2)
        case .vague: .yellow.opacity(0.35)
        case .mastered: .clear
        }
    }
}
