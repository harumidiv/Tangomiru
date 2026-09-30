import Foundation
import Synchronization
@testable import Tangomiru

nonisolated struct FakeDictionary: WordDictionary {
    var entries: [String: String]

    /// "run#noun" のように品詞付きのキーがあればそれを優先する
    func meaning(for key: String, partOfSpeech: PartOfSpeech?) -> String? {
        if let partOfSpeech, let meaning = entries["\(key)#\(partOfSpeech.rawValue)"] { return meaning }
        return entries[key]
    }

    func randomMeanings(count: Int, using rng: inout SeededRandom) -> [String] {
        Array(entries.values.sorted().prefix(count))
    }
}

/// トークン列を手で組み立てる。
/// "ran/run" は原形指定、"Tokyo*" は固有名詞、"run:noun" は品詞指定、"," は句読点（次の語は直結しない）、"." は文の区切り。
nonisolated func tokenized(_ specs: [String], sentences: [String] = ["context"]) -> TokenizedText {
    var tokens: [Token] = []
    var location = 0
    var sentence = 0
    var afterBreak = true
    for spec in specs {
        if spec == "," || spec == "." {
            if spec == "." { sentence += 1 }
            afterBreak = true
            location += 2
            continue
        }
        var text = spec
        var partOfSpeech = PartOfSpeech.other
        if let colon = text.firstIndex(of: ":") {
            partOfSpeech = PartOfSpeech(rawValue: String(text[text.index(after: colon)...])) ?? .other
            text = String(text[..<colon])
        }
        let isProper = text.hasSuffix("*")
        if isProper { text.removeLast() }
        let parts = text.split(separator: "/", maxSplits: 1).map(String.init)
        let surface = parts[0]
        let lemma = parts.count > 1 ? parts[1] : surface.lowercased()
        let length = (surface as NSString).length
        tokens.append(Token(
            surface: surface,
            lemma: lemma,
            span: TextSpan(location: location, length: length),
            sentenceIndex: sentence,
            isProperNoun: isProper,
            followsPreviousDirectly: !afterBreak,
            partOfSpeech: partOfSpeech
        ))
        location += length + 1
        afterBreak = false
    }
    return TokenizedText(tokens: tokens, sentences: sentences)
}

nonisolated struct FakeError: Error {}

nonisolated struct FakeEnricher: VocabEnricher {
    var isAvailable = true
    let handler: @Sendable ([EnrichmentInput], [String]) throws -> EnrichmentOutput

    func enrich(_ inputs: [EnrichmentInput], sentences: [String]) async throws -> EnrichmentOutput {
        try handler(inputs, sentences)
    }
}

nonisolated final class CallRecorder: Sendable {
    private let storage = Mutex<[[String]]>([])

    func record(_ terms: [String]) {
        storage.withLock { $0.append(terms) }
    }

    var calls: [[String]] { storage.withLock { $0 } }
}

nonisolated struct FakeSentenceAnalyzer: SentenceAnalyzer {
    var isAvailable = true
    let handler: @Sendable (String) throws -> SentenceAnalysis

    func analyze(_ sentence: String) async throws -> SentenceAnalysis {
        try handler(sentence)
    }
}

nonisolated struct FakeComprehensionGenerator: ComprehensionQuestionGenerator {
    var isAvailable = true
    let handler: @Sendable (String, Int) throws -> [ComprehensionQuestion]

    func generate(from passage: String, count: Int) async throws -> [ComprehensionQuestion] {
        try handler(passage, count)
    }
}
