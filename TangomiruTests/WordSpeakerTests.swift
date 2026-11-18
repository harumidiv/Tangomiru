import AVFoundation
import Testing
@testable import Tangomiru

struct WordSpeakerTests {
    @Test func utteranceUsesEnglishVoice() {
        let utterance = WordSpeaker.utterance(for: "sector")
        #expect(utterance.speechString == "sector")
        #expect(utterance.voice?.language.hasPrefix("en") == true)
    }

    @Test func appAudioPlaysInSilentModeWithoutStoppingOtherAudio() {
        #expect(AppAudioSession.category == .playback)
        #expect(AppAudioSession.options.contains(.mixWithOthers))
    }

    @MainActor
    @Test func stopClearsPlaybackWhileAudioIsPreparing() {
        let speaker = WordSpeaker()
        #expect(!speaker.isPlaying)
        speaker.speak("The train arrives at noon.")
        #expect(speaker.isPlaying)
        speaker.stop()
        #expect(!speaker.isPlaying)
    }
}
