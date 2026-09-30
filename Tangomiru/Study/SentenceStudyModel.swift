import Foundation
import Observation

/// 1文ずつ学ぶ画面の進行。英文を表示し、「和訳と解説を見る」で和訳と解説を見せる。
/// 保存済みの解説はそのまま使い、無い文だけ作って onAnalyzed で保存に回す。
/// 表示中の文と次の文の解説を先に作っておき、待ち時間を減らす
@Observable
final class SentenceStudyModel {
    enum LoadState: Equatable {
        case loading
        case loaded(SentenceAnalysis)
        case failed
    }

    let sentences: [String]
    private let analyzer: any SentenceAnalyzer
    private let onAnalyzed: ((String, SentenceAnalysis) -> Void)?
    private(set) var index = 0
    /// 和訳と解説を表示しているか
    private(set) var isRevealed = false
    private var states: [Int: LoadState] = [:]
    private var tasks: [Int: Task<Void, Never>] = [:]

    /// saved は英文 → 保存済みの解説
    init(
        sentences: [String],
        saved: [String: SentenceAnalysis] = [:],
        analyzer: any SentenceAnalyzer,
        onAnalyzed: ((String, SentenceAnalysis) -> Void)? = nil
    ) {
        self.sentences = sentences
        self.analyzer = analyzer
        self.onAnalyzed = onAnalyzed
        for (index, sentence) in sentences.enumerated() {
            if let analysis = saved[sentence] { states[index] = .loaded(analysis) }
        }
    }

    var isFinished: Bool { index >= sentences.count }
    var currentSentence: String? { sentences.indices.contains(index) ? sentences[index] : nil }
    var currentState: LoadState? { states[index] }

    var currentAnalysis: SentenceAnalysis? {
        if case .loaded(let analysis)? = states[index] { return analysis }
        return nil
    }

    func start() {
        prepareAround(index)
    }

    func reveal() {
        isRevealed = true
    }

    func next() {
        guard !isFinished else { return }
        index += 1
        isRevealed = false
        prepareAround(index)
    }

    func retry() {
        states[index] = nil
        load(index)
    }

    func cancelAll() {
        tasks.values.forEach { $0.cancel() }
    }

    /// テストで読み込みの完了を待つため
    func pendingTask(at index: Int) -> Task<Void, Never>? {
        tasks[index]
    }

    private func prepareAround(_ index: Int) {
        load(index)
        load(index + 1)
    }

    private func load(_ index: Int) {
        guard sentences.indices.contains(index), states[index] == nil else { return }
        states[index] = .loading
        let sentence = sentences[index]
        let analyzer = analyzer
        tasks[index] = Task { [weak self] in
            let analysis = try? SentenceAnalysisValidator.validated(await analyzer.analyze(sentence))
            guard !Task.isCancelled, let self else { return }
            states[index] = analysis.map(LoadState.loaded) ?? .failed
            if let analysis { onAnalyzed?(sentence, analysis) }
        }
    }
}
