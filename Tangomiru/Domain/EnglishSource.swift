import Foundation

/// 英文を探すための、無料で読める英語ニュース・学習サイト（外部ブラウザで開く）
nonisolated struct EnglishSource: Identifiable, Hashable, Sendable {
    enum Category: CaseIterable, Sendable {
        case learner
        case news

        var title: String {
            switch self {
            case .learner: "やさしい英語（学習者向け）"
            case .news: "英語ニュース"
            }
        }
    }

    let name: String
    let summary: String
    let url: URL
    let category: Category

    var id: URL { url }

    static let all: [EnglishSource] = [
        EnglishSource(name: "News in Levels", summary: "同じニュースを3段階のレベルで読める", url: URL(string: "https://www.newsinlevels.com/")!, category: .learner),
        EnglishSource(name: "Breaking News English", summary: "ニュースを7段階のレベル別教材にしたサイト", url: URL(string: "https://breakingnewsenglish.com/")!, category: .learner),
        EnglishSource(name: "VOA Learning English", summary: "学習者向けのやさしい英語で書かれたニュース", url: URL(string: "https://learningenglish.voanews.com/")!, category: .learner),
        EnglishSource(name: "BBC Learning English", summary: "BBC の英語学習者向け記事・番組", url: URL(string: "https://www.bbc.co.uk/learningenglish/")!, category: .learner),
        EnglishSource(name: "NHK WORLD-JAPAN", summary: "日本のニュースを英語で", url: URL(string: "https://www3.nhk.or.jp/nhkworld/en/news/")!, category: .news),
        EnglishSource(name: "BBC News", summary: "イギリス発の世界のニュース", url: URL(string: "https://www.bbc.com/news")!, category: .news),
        EnglishSource(name: "The Guardian", summary: "イギリスの新聞。世界のニュースや特集記事", url: URL(string: "https://www.theguardian.com/international")!, category: .news),
        EnglishSource(name: "NPR", summary: "アメリカの公共ラジオのニュース", url: URL(string: "https://www.npr.org/")!, category: .news),
        EnglishSource(name: "AP News", summary: "アメリカの通信社による世界のニュース", url: URL(string: "https://apnews.com/")!, category: .news),
    ]

    static func defaults(in category: Category) -> [EnglishSource] {
        all.filter { $0.category == category }
    }
}
