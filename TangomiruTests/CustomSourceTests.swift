import Foundation
import SwiftData
import Testing
@testable import Tangomiru

struct CustomSourceTests {
    @Test(arguments: [
        ("https://example.com/news", "https://example.com/news"),
        ("example.com", "https://example.com"),
        ("  www.example.org/path?q=1  ", "https://www.example.org/path?q=1"),
        ("http://example.net", "http://example.net"),
    ])
    func normalizesURL(input: String, expected: String) {
        #expect(CustomSource.normalizedURL(from: input)?.absoluteString == expected)
    }

    @Test(arguments: ["", "   ", "not a url", "ftp://example.com", "https://", "localhost"])
    func rejectsInvalidURL(input: String) {
        #expect(CustomSource.normalizedURL(from: input) == nil)
    }

    @Test func savesAndFetches() throws {
        let context = ModelContext(try ModelContainer(for: CustomSource.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true)))
        context.insert(CustomSource(name: "My News", url: URL(string: "https://example.com")!))
        try context.save()
        let fetched = try context.fetch(FetchDescriptor<CustomSource>())
        #expect(fetched.map(\.name) == ["My News"])
        #expect(fetched.first?.url == URL(string: "https://example.com"))
    }
}
