import UIKit

/// バックグラウンドでのダウンロード（和訳モデル）が終わり、OS がアプリを起こしたときの知らせを受け取る
final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        guard identifier == BackgroundModelDownloader.sessionIdentifier else {
            completionHandler()
            return
        }
        nonisolated(unsafe) let completionHandler = completionHandler
        BackgroundModelDownloader.shared.backgroundCompletionHandler = { completionHandler() }
        BackgroundModelDownloader.shared.reconnect()
    }
}
