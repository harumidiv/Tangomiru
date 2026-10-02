import AVFoundation
import Testing
@testable import Tangomiru

struct WordListReaderTests {
    @Test func buildsOneUtterancePerWordWithPause() {
        let utterances = WordListReader.utterances(for: ["abyss", "ballad"])
        #expect(utterances.map(\.speechString) == ["abyss", "ballad"])
        #expect(utterances.allSatisfy { $0.postUtteranceDelay == WordListReader.pause })
    }

    @Test func tracksCurrentWordWhileReading() {
        let reader = WordListReader(synthesizing: false)
        reader.read(["abyss", "ballad", "cactus"])
        #expect(reader.isReading)
        reader.didStartWord(at: 1)
        #expect(reader.currentIndex == 1)
        reader.didFinishWord(at: 1)
        #expect(reader.isReading)
        reader.didFinishWord(at: 2)
        #expect(!reader.isReading)
        #expect(reader.currentIndex == nil)
    }

    @Test func stopClearsState() {
        let reader = WordListReader(synthesizing: false)
        reader.read(["abyss", "ballad"])
        reader.didStartWord(at: 0)
        reader.stop()
        #expect(!reader.isReading)
        #expect(reader.currentIndex == nil)
    }

    @Test func emptyListDoesNothing() {
        let reader = WordListReader(synthesizing: false)
        reader.read([])
        #expect(!reader.isReading)
    }
}
