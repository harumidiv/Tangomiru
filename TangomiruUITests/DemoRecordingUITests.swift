import UIKit
import XCTest

/// App プレビュー（動画）の撮影用。見本の英文を貼り付けて抽出し、クイズと読解モードまでを操作する。
/// 録画は外から simctl で行うので、ここでは操作だけを、人が触るくらいの間を空けて行う
final class DemoRecordingUITests: XCTestCase {
    private static let sample = """
    In many crowded cities, empty rooftops are being transformed into vibrant vegetable gardens. \
    Local volunteers cultivate tomatoes, herbs, and beans in places that were once ignored. \
    These projects reduce the distance food must travel, which helps cut emissions from transport. \
    Residents say the gardens also encourage neighbors to get to know one another.
    """

    /// 撮影モードの見本データ（ScreenshotSamples）と同じ、英単語と正しい意味
    private static let meanings = [
        "crowded": "混雑した", "rooftop": "屋上", "transform": "変える", "vibrant": "活気のある",
        "volunteer": "ボランティア", "cultivate": "栽培する", "ignore": "無視する", "reduce": "減らす",
        "emission": "排出", "transport": "輸送", "encourage": "促す", "get to know": "知り合いになる",
    ]

    @MainActor
    func testRecordDemo() throws {
        let app = XCUIApplication()
        app.launchArguments = ["-screenshot", "demo", "-AppleLanguages", "(ja)", "-AppleLocale", "ja_JP"]
        app.launch()
        pause(1.2)

        // 英文を追加 → 本文に貼り付け
        app.buttons["英文を追加"].tap()
        pause(0.8)
        UIPasteboard.general.string = Self.sample
        let editor = app.textViews.firstMatch
        XCTAssertTrue(editor.waitForExistence(timeout: 5))
        editor.tap()
        pause(0.3)
        editor.press(forDuration: 0.6)
        let paste = app.menuItems.matching(NSPredicate(format: "label IN %@", ["ペースト", "Paste"])).firstMatch
        XCTAssertTrue(paste.waitForExistence(timeout: 5))
        paste.tap()
        pause(1.2)

        // 抽出 → 抽出結果
        app.buttons["抽出"].tap()
        XCTAssertTrue(app.navigationBars["抽出結果"].waitForExistence(timeout: 60))
        pause(1.0)
        app.swipeUp(velocity: .slow)
        pause(0.5)
        app.buttons["保存"].tap()
        pause(1.0)

        // ライブラリ → 詳細 → クイズ（正しい意味を選ぶ）
        app.staticTexts.matching(NSPredicate(format: "label BEGINSWITH %@", "In many crowded")).firstMatch.tap()
        pause(1.0)
        app.buttons["クイズを始める"].tap()
        pause(1.0)
        for _ in 0..<4 {
            guard let meaning = currentMeaning(in: app) else { break }
            pause(0.7)
            app.buttons.matching(NSPredicate(format: "label CONTAINS %@", meaning)).firstMatch.tap()
            pause(1.4)
        }
        app.buttons["閉じる"].firstMatch.tap()
        pause(0.8)

        // 読解モード → 単語をタップして意味を確認
        app.buttons["読解モード"].tap()
        pause(1.2)
        let word = app.links.firstMatch
        if word.waitForExistence(timeout: 5) {
            word.tap()
            pause(2.2)
        }
    }

    /// 出題中の英単語の正しい意味
    private func currentMeaning(in app: XCUIApplication) -> String? {
        let deadline = Date().addingTimeInterval(5)
        while Date() < deadline {
            for (term, meaning) in Self.meanings where app.staticTexts[term].exists {
                return meaning
            }
            pause(0.1)
        }
        return nil
    }

    private func pause(_ seconds: TimeInterval) {
        Thread.sleep(forTimeInterval: seconds)
    }
}
