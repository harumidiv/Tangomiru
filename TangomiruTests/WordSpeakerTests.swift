import AVFoundation
import Testing
@testable import Tangomiru

struct WordSpeakerTests {
    @Test func utteranceUsesEnglishVoice() {
        let utterance = WordSpeaker.utterance(for: "sector")
        #expect(utterance.speechString == "sector")
        #expect(utterance.voice?.language.hasPrefix("en") == true)
    }
}
