import SwiftUI

struct VocabLabel: View {
    let term: String
    let meaning: String
    let state: MasteryState?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 8) {
                Text(term).font(.headline)
                if let state { MasteryBadge(state: state) }
            }
            Text(meaning)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
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
