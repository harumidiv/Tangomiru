import Foundation
import Testing
@testable import Tangomiru

struct ChoiceBuilderTests {
    @Test func usesAIDistractorsFirst() {
        let card = makeCard("apple", score: nil, distractors: ["梨", "桃", "柿"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["犬", "猫"], fallbackMeanings: ["空"], using: &rng)
        #expect(Set(choices) == ["appleのいみ", "梨", "桃", "柿"])
    }

    @Test func fillsFromPassageBeforeFallback() {
        let card = makeCard("apple", score: nil, distractors: ["梨"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["犬", "猫"], fallbackMeanings: ["空", "海"], using: &rng)
        #expect(Set(choices) == ["appleのいみ", "梨", "犬", "猫"])
    }

    @Test func excludesCorrectAnswerAndDuplicates() {
        let card = makeCard("apple", score: nil, distractors: ["appleのいみ", "梨", "梨"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(
            for: card, passageMeanings: ["appleのいみ", "犬"], fallbackMeanings: ["海", "空"], using: &rng
        )
        #expect(choices.count == 4)
        #expect(Set(choices).count == 4)
        #expect(choices.filter { $0 == "appleのいみ" }.count == 1)
        #expect(choices.contains("梨"))
        #expect(choices.contains("犬"))
    }

    @Test func skipsCandidatesSharingKanjiWithAnswer() {
        let card = QuizCard(
            id: UUID(), term: "react", meaning: "反応する", distractors: ["応答する", "出発する", "借りる"],
            contextSentence: "", highlight: "react", score: nil
        )
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(
            for: card, passageMeanings: ["反対する", "眠る"], fallbackMeanings: [], using: &rng
        )
        #expect(Set(choices) == ["反応する", "出発する", "借りる", "眠る"])
    }

    @Test func returnsFewerChoicesWhenPoolIsSmall() {
        let card = makeCard("apple", score: nil)
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["appleのいみ"], fallbackMeanings: ["犬"], using: &rng)
        #expect(Set(choices) == ["appleのいみ", "犬"])
    }

    @Test func correctAnswerPositionVaries() {
        let card = makeCard("apple", score: nil, distractors: ["梨", "桃", "柿"])
        var positions = Set<Int>()
        for seed in 1...20 {
            var rng = SeededRandom(seed: UInt64(seed))
            let choices = ChoiceBuilder.choices(for: card, passageMeanings: [], fallbackMeanings: [], using: &rng)
            positions.insert(choices.firstIndex(of: "appleのいみ")!)
        }
        #expect(positions.count > 1)
    }
}
