import Foundation
import Observation

/// 内容理解クイズの進行。最初のチャンクの問題ができたら出題を始め、残りは解いている間に作る
@Observable
final class ComprehensionQuizModel {
    let passage: String
    let plannedCount: Int
    private let chunks: [String]
    private let generator: any ComprehensionQuestionGenerator

    private(set) var questions: [ComprehensionQuestion] = []
    private(set) var index = 0
    private(set) var selectedIndex: Int?
    private(set) var isGenerating = false
    private(set) var correctCount = 0
    private(set) var wrongQuestions: [ComprehensionQuestion] = []
    /// テストで生成の完了を待つため
    private(set) var generationTask: Task<Void, Never>?

    init(passage: String, maxChunkLength: Int = ComprehensionPlanner.maxChunkLength, generator: any ComprehensionQuestionGenerator) {
        let sentences = SentenceSplitter.sentences(in: passage)
        self.passage = passage
        self.plannedCount = ComprehensionPlanner.questionCount(sentenceCount: sentences.count)
        self.chunks = ComprehensionPlanner.chunks(of: sentences, maxLength: maxChunkLength)
        self.generator = generator
    }

    /// 生成中は予定の問題数、生成後は実際に作れた問題数
    var totalCount: Int {
        isGenerating || generationTask == nil ? plannedCount : questions.count
    }

    var current: ComprehensionQuestion? { questions.indices.contains(index) ? questions[index] : nil }
    /// 次の問題をまだ作っている最中
    var isWaiting: Bool { current == nil && isGenerating }
    var isFinished: Bool { !isGenerating && !questions.isEmpty && index >= questions.count }
    /// 生成を終えたのに1問も作れなかった
    var hasFailed: Bool { generationTask != nil && !isGenerating && questions.isEmpty }

    var isCurrentCorrect: Bool? {
        guard let selectedIndex, let current else { return nil }
        return selectedIndex == current.answerIndex
    }

    func start() {
        guard generationTask == nil else { return }
        generate()
    }

    func retry() {
        guard hasFailed else { return }
        generate()
    }

    func answer(_ choiceIndex: Int) {
        guard let current, selectedIndex == nil else { return }
        selectedIndex = choiceIndex
        if choiceIndex == current.answerIndex {
            correctCount += 1
        } else {
            wrongQuestions.append(current)
        }
    }

    func next() {
        guard selectedIndex != nil else { return }
        selectedIndex = nil
        index += 1
    }

    func cancel() {
        generationTask?.cancel()
    }

    private func generate() {
        isGenerating = true
        let plan = Array(zip(chunks, ComprehensionPlanner.questionsPerChunk(total: plannedCount, chunkCount: chunks.count)))
        let generator = generator
        let passage = passage
        generationTask = Task { [weak self] in
            for (chunk, count) in plan where count > 0 {
                if Task.isCancelled { break }
                do {
                    let generated = try await generator.generate(from: chunk, count: count)
                    let valid = generated.compactMap { ComprehensionValidator.validated($0, passage: passage) }
                    self?.questions += valid.prefix(count)
                } catch {
                    // このチャンクの問題は作れなかったので、残りのチャンクで続ける
                    continue
                }
            }
            self?.isGenerating = false
        }
    }
}
