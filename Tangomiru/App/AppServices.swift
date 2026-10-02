import Foundation
import Observation

/// 辞書などアプリ全体で共有するリソース
@Observable
final class AppServices {
    enum Status {
        case loading
        case ready
        case failed(String)

        var isReady: Bool {
            if case .ready = self { return true }
            return false
        }
    }

    private(set) var status: Status = .loading
    /// 英文の抽出中に出す全画面広告（アプリ全体で1つを使い回す）
    let extractionAd: any InterstitialAdPresenting = GoogleInterstitialAdPresenter()
    /// クイズを解き終わったときに出す全画面広告（静止画のみ）
    let quizResultAd: any InterstitialAdPresenting = GoogleInterstitialAdPresenter(adUnitID: AdConfig.quizResultInterstitialUnitID)
    private var dictionary: EJDictionary?
    private var basicWords: Set<String> = []

    func load() async {
        guard dictionary == nil else { return }
        do {
            let loaded = try await Task.detached(priority: .userInitiated) {
                (try EJDictionary.loadBundled(), try BasicWords.loadBundled())
            }.value
            dictionary = loaded.0
            basicWords = loaded.1
            status = .ready
        } catch {
            status = .failed("辞書データを読み込めませんでした。アプリを再インストールしてください。")
        }
    }

    /// includeBasicWords が true なら基本語も出題に含める（機能語は除外）
    func makePipeline(includeBasicWords: Bool = false) -> ExtractionPipeline? {
        guard let dictionary else { return nil }
        let excluded = BasicWords.excludedWords(basic: basicWords, includeBasicWords: includeBasicWords)
        return ExtractionPipeline(
            extractor: DictionaryExtractor(dictionary: dictionary, basicWords: excluded),
            enricher: FoundationModelsEnricher()
        )
    }

    /// 以前の形式で保存された意味を1つの意味に作り直す（辞書の読み込み後に呼ぶ）
    func migrateMeanings(of passages: [Passage]) {
        guard let dictionary else { return }
        let tokenizer = Tokenizer()
        for passage in passages {
            MeaningMigration.migrate(passage, tokenizer: tokenizer, dictionary: dictionary)
        }
    }

    /// 誤答が足りないときの補充用に、辞書からランダムな訳を返す
    func fallbackMeanings(count: Int = 30) -> [String] {
        guard let dictionary else { return [] }
        var rng = SeededRandom()
        return dictionary.randomMeanings(count: count, using: &rng)
    }
}
