import Foundation
import Observation

/// 1文ずつ学ぶ画面の進行。英文と確認問題を先に出し、答えたら和訳と解説を見せる。
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
    private(set) var index = 0
    /// 和訳と解説を表示しているか（確認問題に答えるか、問題が無いときに「和訳と解説を見る」を押すと true）
    private(set) var isRevealed = false
    private(set) var selectedQuizIndex: Int?
    private var states: [Int: LoadState] = [:]
    private var tasks: [Int: Task<Void, Never>] = [:]

    init(sentences: [String], analyzer: any SentenceAnalyzer) {
        self.sentences = sentences
        self.analyzer = analyzer
    }

    var isFinished: Bool { index >= sentences.count }
    var currentSentence: String? { sentences.indices.contains(index) ? sentences[index] : nil }
    var currentState: LoadState? { states[index] }

    var currentAnalysis: SentenceAnalysis? {
        if case .loaded(let analysis)? = states[index] { return analysis }
        return nil
    }

    var isQuizCorrect: Bool? {
        guard let selectedQuizIndex, let quiz = currentAnalysis?.quiz else { return nil }
        return selectedQuizIndex == quiz.answerIndex
    }

    func start() {
        prepareAround(index)
    }

    func reveal() {
        isRevealed = true
    }

    /// 確認問題に答えると和訳と解説を表示する
    func answerQuiz(_ choiceIndex: Int) {
        guard selectedQuizIndex == nil else { return }
        selectedQuizIndex = choiceIndex
        isRevealed = true
    }

    func next() {
        guard !isFinished else { return }
        index += 1
        isRevealed = false
        selectedQuizIndex = nil
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
            let state: LoadState
            do {
                var analysis = SentenceAnalysisValidator.validated(try await analyzer.analyze(sentence), sentence: sentence)
                // 確認問題だけ壊れていたら1回作り直す。作り直しても駄目なら最初の解説を使う
                if analysis != nil, analysis?.quiz == nil,
                   let retried = try? await analyzer.analyze(sentence),
                   let validRetry = SentenceAnalysisValidator.validated(retried, sentence: sentence),
                   validRetry.quiz != nil {
                    analysis = validRetry
                }
                state = analysis.map(LoadState.loaded) ?? .failed
            } catch {
                state = .failed
            }
            guard !Task.isCancelled else { return }
            self?.states[index] = state
        }
    }
}
