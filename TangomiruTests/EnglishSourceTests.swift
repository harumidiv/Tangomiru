import Foundation
import Testing
@testable import Tangomiru

struct EnglishSourceTests {
    @Test func everyCategoryHasSources() {
        for category in EnglishSource.Category.allCases {
            #expect(!EnglishSource.defaults(in: category).isEmpty)
        }
    }

    @Test func urlsAreHTTPSAndUnique() {
        let urls = EnglishSource.all.map(\.url)
        #expect(urls.allSatisfy { $0.scheme == "https" && $0.host() != nil })
        #expect(Set(urls).count == urls.count)
    }

    @Test func includesRequestedSites() {
        let names = EnglishSource.all.map(\.name)
        #expect(names.contains("NHK WORLD-JAPAN"))
        #expect(names.contains("BBC News"))
    }
}
