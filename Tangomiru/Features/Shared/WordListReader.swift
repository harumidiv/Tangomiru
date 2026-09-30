@preconcurrency import AVFoundation
import Observation

/// 単語の一覧を順番に読み上げ、今どの語を読んでいるかを知らせる
@Observable
final class WordListReader {
    /// 語と語の間の間（秒）
    static let pause: TimeInterval = 0.6

    private(set) var isReading = false
    private(set) var currentIndex: Int?

    @ObservationIgnored private let synthesizer: AVSpeechSynthesizer?
    @ObservationIgnored private let delegate = SpeechDelegate()
    @ObservationIgnored private var indices: [ObjectIdentifier: Int] = [:]
    @ObservationIgnored private var count = 0

    /// synthesizing が false なら実際には読み上げない（テスト用）
    init(synthesizing: Bool = true) {
        synthesizer = synthesizing ? AVSpeechSynthesizer() : nil
        if synthesizing { AppAudioSession.configure() }
        synthesizer?.delegate = delegate
        delegate.onStart = { [weak self] id in
            guard let self, let index = indices[id] else { return }
            didStartWord(at: index)
        }
        delegate.onFinish = { [weak self] id in
            guard let self, let index = indices[id] else { return }
            didFinishWord(at: index)
        }
    }

    func read(_ words: [String]) {
        stop()
        guard !words.isEmpty else { return }
        count = words.count
        isReading = true
        for (index, utterance) in Self.utterances(for: words).enumerated() {
            indices[ObjectIdentifier(utterance)] = index
            synthesizer?.speak(utterance)
        }
    }

    func stop() {
        indices = [:]
        synthesizer?.stopSpeaking(at: .immediate)
        isReading = false
        currentIndex = nil
    }

    func didStartWord(at index: Int) {
        guard isReading else { return }
        currentIndex = index
    }

    func didFinishWord(at index: Int) {
        guard index >= count - 1 else { return }
        isReading = false
        currentIndex = nil
    }

    static func utterances(for words: [String]) -> [AVSpeechUtterance] {
        words.map { word in
            let utterance = WordSpeaker.utterance(for: word)
            utterance.postUtteranceDelay = pause
            return utterance
        }
    }
}

/// AVSpeechSynthesizer の通知を MainActor に戻して渡す
private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    var onStart: ((ObjectIdentifier) -> Void)?
    var onFinish: ((ObjectIdentifier) -> Void)?

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didStart utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.onStart?(id) }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        let id = ObjectIdentifier(utterance)
        Task { @MainActor [weak self] in self?.onFinish?(id) }
    }
}
