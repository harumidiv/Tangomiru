import Testing
@testable import Tangomiru

struct ComprehensionPlannerTests {
    @Test(arguments: [(1, 3), (6, 3), (7, 4), (14, 7), (20, 10), (30, 10)] as [(Int, Int)])
    func questionCountFollowsSentenceCount(sentences: Int, expected: Int) {
        #expect(ComprehensionPlanner.questionCount(sentenceCount: sentences) == expected)
    }

    @Test func groupsSentencesIntoChunksUnderLimit() {
        let sentences = ["aaaa.", "bbbb.", "cccc.", "dddd."]
        #expect(ComprehensionPlanner.chunks(of: sentences, maxLength: 11) == ["aaaa. bbbb.", "cccc. dddd."])
    }

    @Test func keepsOverlongSentenceAsItsOwnChunk() {
        #expect(ComprehensionPlanner.chunks(of: ["short.", String(repeating: "x", count: 20), "end."], maxLength: 10)
            == ["short.", String(repeating: "x", count: 20), "end."])
    }

    @Test func spreadsQuestionsAcrossChunks() {
        #expect(ComprehensionPlanner.questionsPerChunk(total: 5, chunkCount: 2) == [3, 2])
        #expect(ComprehensionPlanner.questionsPerChunk(total: 3, chunkCount: 6) == [1, 0, 1, 0, 1, 0])
        #expect(ComprehensionPlanner.questionsPerChunk(total: 4, chunkCount: 1) == [4])
    }
}
