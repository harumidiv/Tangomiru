import Foundation
import Testing
@testable import Tangomiru

struct QuizSoundPlayerTests {
    @Test(arguments: [QuizSoundPlayer.Sound.correct, .wrong])
    func bundledSoundLoads(sound: QuizSoundPlayer.Sound) {
        #expect(QuizSoundPlayer.url(for: sound) != nil)
        #expect(QuizSoundPlayer().canPlay(sound))
    }
}
