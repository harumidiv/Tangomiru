import SwiftUI

struct QuizResultView: View {
    let session: QuizSession
    let onClose: () -> Void

    var body: some View {
        let promoted = session.changes.filter(\.isPromotion)
        let demoted = session.changes.filter(\.isDemotion)
        List {
            Section {
                Text("\(session.correctCount) / \(session.questionCount) 問正解")
                    .font(.title.bold())
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
            if !promoted.isEmpty {
                Section("上がった語") {
                    ForEach(promoted, id: \.cardID) { ChangeRow(change: $0) }
                }
            }
            if !demoted.isEmpty {
                Section("下がった語") {
                    ForEach(demoted, id: \.cardID) { ChangeRow(change: $0) }
                }
            }
        }
        .navigationTitle("結果")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("完了", action: onClose)
            }
        }
    }
}

private struct ChangeRow: View {
    let change: ScoreChange

    var body: some View {
        HStack {
            Text(change.term).font(.headline)
            Spacer()
            MasteryBadge(state: MasteryState(score: change.before))
            Image(systemName: "arrow.right").font(.caption).foregroundStyle(.secondary)
            MasteryBadge(state: MasteryState(score: change.after))
        }
    }
}
