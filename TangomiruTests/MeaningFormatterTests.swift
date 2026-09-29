import Testing
@testable import Tangomiru

struct MeaningFormatterTests {
    @Test func keepsFirstTwoSensesAndStripsMarkup() {
        let raw = "『走る』,駆ける / 〈人が〉(…に)『急ぐ』,突進する《+『for』(『to』)+『名』》 / 〈C〉『走ること』"
        #expect(MeaningFormatter.format(raw) == "走る,駆ける / 〈人が〉(…に)急ぐ,突進する")
    }

    @Test func removesCountabilityTags() {
        #expect(MeaningFormatter.clean("〈C〉『走ること』,駆け足;〈U〉走力") == "走ること,駆け足;走力")
    }

    @Test func dropsEmptyAndDuplicateSenses() {
        #expect(MeaningFormatter.format("《米》 / 猫 / 猫 / 犬") == "猫 / 犬")
    }

    @Test func emptyInputGivesEmpty() {
        #expect(MeaningFormatter.format("") == "")
    }
}
