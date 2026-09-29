import Testing
@testable import Tangomiru

struct ChoiceBuilderTests {
    @Test func usesAIDistractorsFirst() {
        let card = makeCard("apple", score: nil, distractors: ["梨", "桃", "柿"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["犬", "猫"], fallbackMeanings: ["空"], using: &rng)
        #expect(Set(choices) == ["appleの意味", "梨", "桃", "柿"])
    }

    @Test func fillsFromPassageBeforeFallback() {
        let card = makeCard("apple", score: nil, distractors: ["梨"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["犬", "猫"], fallbackMeanings: ["空", "海"], using: &rng)
        #expect(Set(choices) == ["appleの意味", "梨", "犬", "猫"])
    }

    @Test func excludesCorrectAnswerAndDuplicates() {
        let card = makeCard("apple", score: nil, distractors: ["appleの意味", "梨", "梨"])
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(
            for: card, passageMeanings: ["appleの意味", "犬"], fallbackMeanings: ["海", "空"], using: &rng
        )
        #expect(choices.count == 4)
        #expect(Set(choices).count == 4)
        #expect(choices.filter { $0 == "appleの意味" }.count == 1)
        #expect(choices.contains("梨"))
        #expect(choices.contains("犬"))
    }

    @Test func returnsFewerChoicesWhenPoolIsSmall() {
        let card = makeCard("apple", score: nil)
        var rng = SeededRandom(seed: 1)
        let choices = ChoiceBuilder.choices(for: card, passageMeanings: ["appleの意味"], fallbackMeanings: ["犬"], using: &rng)
        #expect(Set(choices) == ["appleの意味", "犬"])
    }

    @Test func correctAnswerPositionVaries() {
        let card = makeCard("apple", score: nil, distractors: ["梨", "桃", "柿"])
        var positions = Set<Int>()
        for seed in 1...20 {
            var rng = SeededRandom(seed: UInt64(seed))
            let choices = ChoiceBuilder.choices(for: card, passageMeanings: [], fallbackMeanings: [], using: &rng)
            positions.insert(choices.firstIndex(of: "appleの意味")!)
        }
        #expect(positions.count > 1)
    }
}
