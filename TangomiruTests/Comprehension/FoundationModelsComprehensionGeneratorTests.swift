import Testing
@testable import Tangomiru

struct FoundationModelsComprehensionGeneratorTests {
    @Test func promptIncludesPassageAndCount() {
        #expect(FoundationModelsComprehensionGenerator.prompt(passage: "People took it for granted.", count: 2) == """
        # 本文
        People took it for granted.
        # 作る問題の数
        2問
        """)
    }

    @Test func availabilityCheckDoesNotCrash() {
        _ = FoundationModelsComprehensionGenerator().isAvailable
    }
}
