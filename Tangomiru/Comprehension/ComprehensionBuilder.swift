import Foundation

/// 内容理解の問題を作る手順。要旨の問題を1問作ってから、本文を分けた各部分から細部の問題を作る。
/// 抽出時にまとめて作る場合（buildAll）と、クイズ中に作りながら出す場合（build）の両方で使う
nonisolated struct ComprehensionBuilder: Sendable {
    static let attemptsPerChunk = 2
    /// 要旨の問題を作るときに渡す本文の上限（端末内 AI のコンテキストに収めるため）
    static let maxGistLength = 2_400

    let passage: String
    let plannedCount: Int
    private let chunks: [String]

    init(passage: String, maxChunkLength: Int = ComprehensionPlanner.maxChunkLength) {
        let sentences = SentenceSplitter.sentences(in: passage)
        self.passage = passage
        self.plannedCount = ComprehensionPlanner.questionCount(sentenceCount: sentences.count)
        self.chunks = ComprehensionPlanner.chunks(of: sentences, maxLength: maxChunkLength)
    }

    /// できた問題を順に onQuestions へ渡す（要旨 → 細部）
    func build(using generator: any ComprehensionQuestionGenerator, onQuestions: ([ComprehensionQuestion]) -> Void) async {
        guard !chunks.isEmpty else { return }
        var detailCount = plannedCount
        if let gist = try? await generator.generateGist(from: String(passage.prefix(Self.maxGistLength))),
           let valid = ComprehensionValidator.validated(gist, passage: passage) {
            onQuestions([valid])
            detailCount -= 1
        }
        let plan = zip(chunks, ComprehensionPlanner.questionsPerChunk(total: detailCount, chunkCount: chunks.count))
        for (chunk, count) in plan where count > 0 {
            var remaining = count
            // 壊れた問題を捨てて足りなくなったら、足りない分だけ1回作り直す
            for _ in 0..<Self.attemptsPerChunk where remaining > 0 {
                if Task.isCancelled { return }
                do {
                    let generated = try await generator.generate(from: chunk, count: remaining)
                    let valid = Array(generated.compactMap { ComprehensionValidator.validated($0, passage: passage) }.prefix(remaining))
                    if !valid.isEmpty { onQuestions(valid) }
                    remaining -= valid.count
                } catch {
                    // このチャンクの問題は作れなかったので、残りのチャンクで続ける
                    break
                }
            }
        }
    }

    func buildAll(using generator: any ComprehensionQuestionGenerator) async -> [ComprehensionQuestion] {
        var all: [ComprehensionQuestion] = []
        await build(using: generator) { all += $0 }
        return all
    }
}
