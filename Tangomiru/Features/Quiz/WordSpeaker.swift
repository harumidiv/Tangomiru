@preconcurrency import AVFoundation

/// 出題された英単語を読み上げる。
/// 効果音はマナーモードで鳴らさない（.ambient）が、読み上げはマナーモードでも聞こえるよう、
/// 読み上げている間だけ .playback に切り替え、終わったら .ambient に戻す
final class WordSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    static let speakingCategory: AVAudioSession.Category = .playback
    /// 他のアプリの音楽は止めず、読み上げ中だけ音量を下げてもらう
    static let speakingOptions: AVAudioSession.CategoryOptions = [.mixWithOthers, .duckOthers]
    static let idleCategory: AVAudioSession.Category = .ambient

    /// メインスレッドからのみ使う（デリゲートの通知も MainActor に戻してから扱う）
    nonisolated(unsafe) private let synthesizer = AVSpeechSynthesizer()

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(Self.speakingCategory, mode: .spokenAudio, options: Self.speakingOptions)
        try? session.setActive(true)
        synthesizer.speak(Self.utterance(for: text))
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }

    static func utterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        return utterance
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.restoreIdleSession() }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor [weak self] in self?.restoreIdleSession() }
    }

    /// 読み上げが終わったら効果音用の設定に戻し、下げていた他のアプリの音量を元に戻す
    private func restoreIdleSession() {
        guard !synthesizer.isSpeaking else { return }
        let session = AVAudioSession.sharedInstance()
        try? session.setActive(false, options: .notifyOthersOnDeactivation)
        try? session.setCategory(Self.idleCategory, mode: .default)
    }
}
