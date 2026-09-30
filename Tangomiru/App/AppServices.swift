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

    func makePipeline() -> ExtractionPipeline? {
        guard let dictionary else { return nil }
        return ExtractionPipeline(
            extractor: DictionaryExtractor(dictionary: dictionary, basicWords: basicWords),
            enricher: FoundationModelsEnricher()
        )
    }

    /// 誤答が足りないときの補充用に、辞書からランダムな訳を返す
    func fallbackMeanings(count: Int = 30) -> [String] {
        guard let dictionary else { return [] }
        var rng = SeededRandom()
        return dictionary.randomMeanings(count: count, using: &rng)
    }
}
