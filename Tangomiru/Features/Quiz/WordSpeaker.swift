import AVFoundation
import Observation

/// 英単語や英文を読み上げる（音の設定は AppAudioSession に従う）
@Observable
final class WordSpeaker: NSObject, AVSpeechSynthesizerDelegate {
    private(set) var isPlaying = false

    private let synthesizer = AVSpeechSynthesizer()
    @ObservationIgnored private var pendingPlayback: Task<Void, Never>?
    @ObservationIgnored private var currentUtteranceID: ObjectIdentifier?
    @ObservationIgnored private var hasStartedPlayback = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String) {
        stop()
        isPlaying = true
        pendingPlayback = Task { [weak self] in
            await AppAudioSession.prepareForPlayback()
            guard !Task.isCancelled, let self else { return }
            pendingPlayback = nil
            let utterance = Self.utterance(for: text)
            if !hasStartedPlayback {
                // 初回は音声出力が立ち上がる時間を取り、文頭の音を保つ。
                utterance.preUtteranceDelay = 0.2
                hasStartedPlayback = true
            }
            currentUtteranceID = ObjectIdentifier(utterance)
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        pendingPlayback?.cancel()
        pendingPlayback = nil
        currentUtteranceID = nil
        isPlaying = false
        synthesizer.stopSpeaking(at: .immediate)
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        playbackEnded(ObjectIdentifier(utterance))
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        playbackEnded(ObjectIdentifier(utterance))
    }

    private nonisolated func playbackEnded(_ id: ObjectIdentifier) {
        Task { @MainActor [weak self] in
            guard let self, currentUtteranceID == id else { return }
            currentUtteranceID = nil
            isPlaying = false
        }
    }

    static func utterance(for text: String) -> AVSpeechUtterance {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        return utterance
    }
}
