import Foundation
import Observation
import os

/// 1文ずつ学ぶ画面の進行。英文を表示し、「和訳と解説を見る」で和訳と解説を見せる。
/// 保存済みの解説はそのまま使い、無い文だけ作って onAnalyzed で保存に回す。
/// 表示中の文と次の文の解説を先に作っておき、待ち時間を減らす。
/// 解説を作れない端末では和訳だけを見せ、和訳だけの結果は保存しない（解説を作れるようになったら作り直すため）
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

    /// 解説まで作れるか（false なら和訳だけを作る）
    var canExplain: Bool { analyzer.canExplain }

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
        let shouldSave = analyzer.canExplain
        tasks[index] = Task { [weak self] in
            var analysis: SentenceAnalysis?
            do {
                analysis = SentenceAnalysisValidator.validated(try await analyzer.analyze(sentence))
                if analysis == nil { SentenceStudyLog.logger.error("和訳が空でした") }
            } catch {
                SentenceStudyLog.logger.error("和訳と解説を作れませんでした: \(String(reflecting: error), privacy: .public)")
            }
            guard !Task.isCancelled, let self else { return }
            states[index] = analysis.map(LoadState.loaded) ?? .failed
            if let analysis, shouldSave, !analysis.isExplanationFailed { onAnalyzed?(sentence, analysis) }
        }
    }
}
