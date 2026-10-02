import Foundation
import FoundationModels

@Generable
nonisolated struct GeneratedEntry: Sendable {
    @Guide(description: "英語の見出し語。入力された語はそのままの綴り、熟語は例文に出てくる形そのまま")
    var term: String
    @Guide(description: "例文で使われている意味を1つだけ。括弧や補足は付けない15文字以内の日本語")
    var meaning: String
    @Guide(description: "正解とは意味がはっきり異なる日本語の誤答。類義語や言い換えは不可。正解と同じく括弧や補足の無い短い語", .count(3))
    var distractors: [String]
}

@Generable
nonisolated struct GeneratedEnrichment: Sendable {
    @Guide(description: "入力された各語の文脈訳と誤答。入力と同じ順番")
    var words: [GeneratedEntry]
    @Guide(description: "例文に含まれるが入力に無い、2語以上の英語の熟語・句動詞", .maximumCount(5))
    var idioms: [GeneratedEntry]
}

nonisolated struct FoundationModelsEnricher: VocabEnricher {
    static let instructions = """
    あなたは日本人の英語学習者のための英和辞書編集者です。
    与えられた英語の語が例文の中でどの意味で使われているかを判断し、その意味を1つだけ日本語で答えてください。
    訳には括弧や補足説明を付けず、複数の訳を並べないでください。
    入力された別々の語に同じ訳を付けないでください（例: return と dividend を両方「配当」にしない）。
    4択クイズ用に、正解と同じ品詞で、意味がはっきり異なる日本語の誤答を3つ作ってください。
    誤答に正解の類義語や言い換えを使わないでください（例: 正解が「反応する」なら「応答する」「返事する」は不可、「出発する」「借りる」などにする）。
    例文に含まれる熟語・句動詞で入力に無いものがあれば、例文に出てくる形のまま追加してください。
    """

    var isAvailable: Bool { SystemLanguageModel.default.isAvailable }

    func enrich(_ inputs: [EnrichmentInput], sentences: [String]) async throws -> EnrichmentOutput {
        // チャンクごとに新しいセッションを使い、コンテキストを溜めない
        let session = LanguageModelSession(instructions: Self.instructions)
        let response = try await session.respond(
            to: Self.prompt(inputs: inputs, sentences: sentences),
            generating: GeneratedEnrichment.self
        )
        let content = response.content
        return EnrichmentOutput(words: content.words.map(Self.entry), idioms: content.idioms.map(Self.entry))
    }

    static func prompt(inputs: [EnrichmentInput], sentences: [String]) -> String {
        var lines = ["# 例文"]
        lines += sentences.map { "- \($0)" }
        lines.append("# 語（見出し語: 辞書の訳）")
        lines += inputs.map { "- \($0.term): \($0.dictionaryMeaning)" }
        return lines.joined(separator: "\n")
    }

    private static func entry(_ generated: GeneratedEntry) -> EnrichedEntry {
        EnrichedEntry(term: generated.term, meaning: generated.meaning, distractors: generated.distractors)
    }
}
