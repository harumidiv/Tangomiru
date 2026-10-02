#if DEBUG
import Foundation
import SwiftData
import SwiftUI

/// App Store 用のスクリーンショット・動画の撮影モード（Debug ビルドのみ）。
/// 起動引数 `-screenshot <画面名>` で、見本データを入れた画面を直接開き、広告と同意画面は出さない。
/// `-screenshot demo` は通常の画面から操作する（動画の撮影用）
enum ScreenshotMode {
    enum Screen: String {
        case library, review, quiz, detail, reading, study, comprehension, demo
    }

    static let screen: Screen? = {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: "-screenshot"), arguments.indices.contains(index + 1) else { return nil }
        return Screen(rawValue: arguments[index + 1])
    }()

    static var isActive: Bool { screen != nil }
}

struct ScreenshotRootView: View {
    let screen: ScreenshotMode.Screen
    let samples: ScreenshotSamples

    var body: some View {
        switch screen {
        case .library, .demo:
            LibraryView()
        case .review:
            NavigationStack {
                ExtractionReviewView(
                    title: samples.main.title, passageBody: samples.main.body,
                    result: samples.extractionResult, onSaved: {}
                )
            }
        case .quiz:
            QuizView(passage: samples.main, length: .ten)
        case .detail:
            NavigationStack { PassageDetailView(passage: samples.main) }
        case .reading:
            NavigationStack { ReadingView(passage: samples.main) }
        case .study:
            SentenceStudyView(model: samples.studyModel())
        case .comprehension:
            ComprehensionQuizView(model: samples.comprehensionModel())
        }
    }
}

/// 撮影用の見本データ（英文はニュースの転載にならないよう、オリジナルの文章）
@MainActor
final class ScreenshotSamples {
    /// 動画（demo）では見本の英文をその場で貼り付けて抽出するので、ライブラリに入れておかない
    static let shared = ScreenshotSamples(includeMain: ScreenshotMode.screen != .demo)

    let container: ModelContainer
    let main: Passage

    static let mainTitle = "Gardens on the Rooftops"
    static let mainBody = """
    In many crowded cities, empty rooftops are being transformed into vibrant vegetable gardens. \
    Local volunteers cultivate tomatoes, herbs, and beans in places that were once ignored. \
    These projects reduce the distance food must travel, which helps cut emissions from transport. \
    Residents say the gardens also encourage neighbors to get to know one another. \
    Some schools have joined the initiative, allowing students to harvest what they plant. \
    Experts believe such efforts could make urban communities more resilient in the face of rising food prices.
    """

    /// (見出し語, 本文中の形, 意味, 誤答, スコア)
    private static let mainWords: [(String, String, String, [String], Int?)] = [
        ("crowded", "crowded", "混雑した", ["静かな", "古い", "広大な"], 2),
        ("rooftop", "rooftops", "屋上", ["地下室", "玄関", "廊下"], 1),
        ("transform", "transformed", "変える", ["守る", "運ぶ", "数える"], 1),
        ("vibrant", "vibrant", "活気のある", ["退屈な", "壊れた", "寒い"], nil),
        ("volunteer", "volunteers", "ボランティア", ["経営者", "観光客", "審判"], 2),
        ("cultivate", "cultivate", "栽培する", ["輸入する", "捨てる", "修理する"], 0),
        ("ignore", "ignored", "無視する", ["祝う", "予約する", "借りる"], 1),
        ("reduce", "reduce", "減らす", ["増やす", "届ける", "隠す"], 2),
        ("emission", "emissions", "排出", ["収入", "招待", "許可"], -1),
        ("transport", "transport", "輸送", ["娯楽", "教育", "天気"], 1),
        ("encourage", "encourage", "促す", ["禁止する", "疑う", "忘れる"], nil),
        ("get to know", "get to know", "知り合いになる", ["仲直りする", "引っ越す", "待ち合わせる"], 2),
        ("initiative", "initiative", "取り組み", ["休日", "苦情", "噂"], 0),
        ("harvest", "harvest", "収穫する", ["泳ぐ", "印刷する", "売り切る"], 2),
        ("resilient", "resilient", "回復力のある", ["不注意な", "有名な", "高価な"], -1),
        ("in the face of", "in the face of", "〜に直面して", ["〜のおかげで", "〜の代わりに", "〜のそばに"], nil),
    ]

    /// ライブラリに並べるほかの英文（タイトル, 本文, スコアの並び）
    private static let otherPassages: [(String, String, [Int?])] = [
        (
            "The Science of a Good Night's Sleep",
            "Researchers have found that a consistent bedtime can improve memory and mood. Even a short nap may restore focus.",
            [2, 2, 2, 1, 2, 2]
        ),
        (
            "Electric Ferries Cross the Harbor",
            "A fleet of quiet electric ferries now carries commuters across the harbor, replacing older diesel vessels.",
            [2, 1, 0, nil, 1]
        ),
        (
            "How Honeybees Share Directions",
            "Honeybees perform a waggle dance to tell their hive where flowers can be found and how far away they are.",
            [nil, nil, 1, nil]
        ),
    ]

    init(includeMain: Bool) {
        let schema = Schema([Passage.self, CustomSource.self])
        container = try! ModelContainer(for: schema, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext

        let day: TimeInterval = 24 * 60 * 60
        for (offset, other) in Self.otherPassages.enumerated() {
            let passage = Passage(title: other.0, body: other.1, usedAI: true, createdAt: .now.addingTimeInterval(-Double(offset + 2) * day))
            context.insert(passage)
            let terms = other.1.split(separator: " ").map { $0.trimmingCharacters(in: .punctuationCharacters) }.filter { $0.count > 5 }
            for (term, score) in zip(terms, other.2) {
                let item = VocabItem(extracted: Self.extracted(term: term.lowercased(), surface: term, meaning: "訳", distractors: [], body: other.1))
                item.score = score
                passage.items.append(item)
            }
            passage.lastStudiedAt = .now.addingTimeInterval(-Double(offset + 1) * day)
        }

        main = Passage(title: Self.mainTitle, body: Self.mainBody, usedAI: true)
        if includeMain {
            context.insert(main)
            for word in Self.mainWords {
                let item = VocabItem(extracted: Self.extracted(term: word.0, surface: word.1, meaning: word.2, distractors: word.3, body: Self.mainBody))
                item.score = word.4
                main.items.append(item)
            }
            main.lastStudiedAt = .now
            main.setComprehensionQuestions(Self.comprehensionQuestions)
        }
    }

    var extractionResult: ExtractionResult {
        ExtractionResult(
            items: Self.mainWords.map { Self.extracted(term: $0.0, surface: $0.1, meaning: $0.2, distractors: $0.3, body: Self.mainBody) },
            usedAI: true
        )
    }

    /// 動画（demo）で見本の英文を貼り付けて抽出したときの結果。
    /// シミュレーターでは Apple Intelligence が使えず辞書の訳になるため、対応端末と同じ文脈に合った訳を返す
    static func demoExtraction(for body: String) -> ExtractionResult? {
        guard ScreenshotMode.screen == .demo, mainBody.hasPrefix(body.trimmingCharacters(in: .whitespacesAndNewlines)) else { return nil }
        let items = mainWords
            .filter { !TextSearch.occurrences(of: $0.1, in: body).isEmpty }
            .map { extracted(term: $0.0, surface: $0.1, meaning: $0.2, distractors: $0.3, body: body) }
        return ExtractionResult(items: items, usedAI: true)
    }

    func studyModel() -> SentenceStudyModel {
        let sentences = SentenceSplitter.sentences(in: Self.mainBody)
        let first = SentenceAnalysis(
            translation: "多くの混雑した都市で、使われていない屋上が活気ある菜園へと生まれ変わりつつある。",
            explanation: "are being transformed は現在進行形の受け身で「変えられている最中だ」という意味。transform A into B で「AをBに変える」を表し、ここでは屋上が菜園に変わっていく様子を伝えている。"
        )
        let model = SentenceStudyModel(sentences: sentences, saved: [sentences[0]: first], analyzer: SavedOnlyAnalyzer())
        model.reveal()
        return model
    }

    func comprehensionModel() -> ComprehensionQuizModel {
        let model = ComprehensionQuizModel(
            passage: Self.mainBody, preloaded: Self.comprehensionQuestions, generator: FoundationModelsComprehensionGenerator()
        )
        model.answer(Self.comprehensionQuestions[0].answerIndex)
        return model
    }

    private static let comprehensionQuestions = [
        ComprehensionQuestion(
            question: "この文章は主に何について書かれていますか？",
            choices: ["新しい高層ビルの建設", "都市の屋上を菜園にする取り組み", "学校給食の値上げ", "郊外への引っ越しの増加"],
            answerIndex: 1,
            evidence: "In many crowded cities, empty rooftops are being transformed into vibrant vegetable gardens."
        ),
        ComprehensionQuestion(
            question: "屋上の菜園は、どのように排出量の削減に役立っていますか？",
            choices: ["食べ物を運ぶ距離が短くなる", "車の利用が禁止される", "工場が屋上に移される", "雨水で発電する"],
            answerIndex: 0,
            evidence: "These projects reduce the distance food must travel, which helps cut emissions from transport."
        ),
        ComprehensionQuestion(
            question: "学校の生徒は何ができるようになりましたか？",
            choices: ["屋上で授業を受けられる", "野菜を無料でもらえる", "自分で植えた作物を収穫できる", "庭の設計を学べる"],
            answerIndex: 2,
            evidence: "Some schools have joined the initiative, allowing students to harvest what they plant."
        ),
    ]

    private static func extracted(term: String, surface: String, meaning: String, distractors: [String], body: String) -> ExtractedItem {
        let spans = TextSearch.occurrences(of: surface, in: body)
        let sentence = SentenceSplitter.sentences(in: body).first { !TextSearch.occurrences(of: surface, in: $0).isEmpty } ?? ""
        return ExtractedItem(
            term: term, meaning: meaning, distractors: distractors, contextSentence: sentence, occurrences: spans, source: .ai
        )
    }
}

/// 保存済みの解説だけを使う（撮影中に AI で作り直さない）
private struct SavedOnlyAnalyzer: SentenceAnalyzer {
    var isAvailable: Bool { true }
    func analyze(_ sentence: String) async throws -> SentenceAnalysis {
        try await Task.sleep(for: .seconds(3600))
        throw CancellationError()
    }
}
#endif
