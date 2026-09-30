import Foundation
import Observation

/// 内容理解クイズの進行。保存済みの問題があればそれを出し、無ければ作りながら出す（最初の問題ができたら出題を始める）
@Observable
final class ComprehensionQuizModel {
    let passage: String
    let plannedCount: Int
    private let builder: ComprehensionBuilder
    private let generator: any ComprehensionQuestionGenerator
    private let isPreloaded: Bool
    /// その場で作った問題を保存するため、生成が終わったら呼ぶ
    private let onGenerated: (([ComprehensionQuestion]) -> Void)?

    private(set) var questions: [ComprehensionQuestion] = []
    private(set) var index = 0
    private(set) var selectedIndex: Int?
    private(set) var isGenerating = false
    private(set) var correctCount = 0
    private(set) var wrongQuestions: [ComprehensionQuestion] = []
    /// テストで生成の完了を待つため
    private(set) var generationTask: Task<Void, Never>?

    /// preloaded（抽出時に作って保存した問題）があればそれを出し、無ければその場で作る
    init(
        passage: String,
        preloaded: [ComprehensionQuestion] = [],
        maxChunkLength: Int = ComprehensionPlanner.maxChunkLength,
        generator: any ComprehensionQuestionGenerator,
        onGenerated: (([ComprehensionQuestion]) -> Void)? = nil
    ) {
        let builder = ComprehensionBuilder(passage: passage, maxChunkLength: maxChunkLength)
        self.passage = passage
        self.builder = builder
        self.plannedCount = preloaded.isEmpty ? builder.plannedCount : preloaded.count
        self.generator = generator
        self.isPreloaded = !preloaded.isEmpty
        self.onGenerated = onGenerated
        self.questions = preloaded
    }

    /// 生成中は予定の問題数、生成後は実際に作れた問題数
    var totalCount: Int {
        isGenerating || (generationTask == nil && !isPreloaded) ? plannedCount : questions.count
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
        guard generationTask == nil, !isPreloaded else { return }
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
        let builder = builder
        let generator = generator
        generationTask = Task { [weak self] in
            await builder.build(using: generator) { batch in self?.questions += batch }
            guard let self else { return }
            isGenerating = false
            if !questions.isEmpty { onGenerated?(questions) }
        }
    }
}
