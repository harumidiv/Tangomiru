import SwiftUI

struct VocabLabel: View {
    let term: String
    let meaning: String
    let state: MasteryState?
    /// true なら英語をグレーで塗りつぶして見えなくする
    var hidesTerm = false
    /// true なら和訳をグレーで塗りつぶして見えなくする
    var hidesMeaning = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(term).font(.headline)
                    .masked(hidesTerm, label: "英語")
                if let state { MasteryBadge(state: state) }
            }
            Text(meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .masked(hidesMeaning, label: "和訳")
        }
    }
}

private extension View {
    /// 文字の大きさはそのままに、グレーの帯で覆って読めなくする
    @ViewBuilder
    func masked(_ isMasked: Bool, label: String) -> some View {
        if isMasked {
            opacity(0)
                .overlay(RoundedRectangle(cornerRadius: 4).fill(Color(.systemGray4)))
                .accessibilityHidden(true)
                .overlay { Color.clear.accessibilityElement().accessibilityLabel("\(label)を隠しています") }
        } else {
            self
        }
    }
}

struct MasteryBadge: View {
    let state: MasteryState

    var body: some View {
        Text(state.label)
            .font(.caption2.bold())
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundStyle(state.color)
            .background(state.color.opacity(0.15), in: .capsule)
    }
}
