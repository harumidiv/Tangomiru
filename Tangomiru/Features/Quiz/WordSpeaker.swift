import AVFoundation

/// 出題された英単語を読み上げる（音の設定は AppAudioSession に従う）
final class WordSpeaker {
    private let synthesizer = AVSpeechSynthesizer()

    init() {
        AppAudioSession.configure()
    }

    func speak(_ text: String) {
        synthesizer.stopSpeaking(at: .immediate)
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
}
