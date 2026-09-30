import Foundation

/// クイズ1問分の元データ（SwiftData に依存しない値型）
nonisolated struct QuizCard: Identifiable, Hashable, Sendable {
    let id: UUID
    let term: String
    let meaning: String
    /// AI が生成した誤答（辞書モードでは空）
    let distractors: [String]
    let contextSentence: String
    /// 例文中で太字にする表記（本文に出てきた形。例: term が "run" なら "running"）
    let highlight: String
    let score: Int?
}
