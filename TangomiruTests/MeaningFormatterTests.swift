import Testing
@testable import Tangomiru

struct MeaningFormatterTests {
    static let run = "『走る』,駆ける / 〈人が〉(…に)『急ぐ』,突進する《+『for』(『to』)+『名』》 / 〈C〉『走ること』,駆け足"

    @Test func verbPrefersSenseWithoutNounMarker() {
        #expect(MeaningFormatter.format(Self.run, partOfSpeech: .verb) == "走る")
    }

    @Test func nounPrefersCountableSense() {
        #expect(MeaningFormatter.format(Self.run, partOfSpeech: .noun) == "走ること")
    }

    @Test func unknownPartOfSpeechUsesFirstSense() {
        #expect(MeaningFormatter.format(Self.run) == "走る")
    }

    @Test func nounFallsBackWhenNoMarkedSense() {
        #expect(MeaningFormatter.format("美しい / きれいな", partOfSpeech: .noun) == "美しい")
    }

    @Test func singleRemovesAllAnnotations() {
        #expect(MeaningFormatter.single("〈人が〉(…に)『急ぐ』,突進する《+『for』+『名』》") == "急ぐ")
        #expect(MeaningFormatter.single("（古）…を変える；変化させる") == "変える")
        #expect(MeaningFormatter.single("至る所にある（偏在する）") == "至る所にある")
        #expect(MeaningFormatter.single("研究者、調査員") == "研究者")
    }

    @Test func prefersEmphasizedMeaning() {
        #expect(MeaningFormatter.single("〈知識・情報・思想など〉を『伝える』,伝達する") == "伝える")
        #expect(MeaningFormatter.single("〈C〉『集会』,『会合』(assembly)") == "集会")
    }

    @Test func dropsLeadingEllipsisAndParticleLeftByAnnotations() {
        #expect(MeaningFormatter.single("…を軽く揺り動かす;…をちょっと押す(突く)") == "軽く揺り動かす")
        #expect(MeaningFormatter.single("〈記憶など〉を呼び起こす,刺激する") == "呼び起こす")
        #expect(MeaningFormatter.single("のろい") == "のろい")
    }

    @Test func skipsCrossReferenceSenses() {
        let raw = "=analyze / 〈状況など〉を『分析する』,詳細に検討する / 《米》〈人〉を精神分析する(psychoanalyze)"
        #expect(MeaningFormatter.format(raw, partOfSpeech: .verb) == "分析する")
        #expect(MeaningFormatter.format(raw) == "分析する")
    }

    @Test func skipsSensesWithoutJapanese() {
        #expect(MeaningFormatter.format("answer / ampere") == "")
        #expect(MeaningFormatter.format("=AA / antiaircraft / 対空の") == "対空の")
    }

    @Test func extractsCrossReferenceTarget() {
        #expect(MeaningFormatter.referenceTarget(in: "=them") == "them")
        #expect(MeaningFormatter.referenceTarget(in: "=it was / ") == "it was")
        #expect(MeaningFormatter.referenceTarget(in: "走る") == nil)
    }

    @Test func skipsSensesThatBecomeEmpty() {
        #expect(MeaningFormatter.format("《米》 / 猫, ねこ") == "猫")
    }

    @Test func emptyInputGivesEmpty() {
        #expect(MeaningFormatter.format("") == "")
    }
}
