import CryptoKit
import Foundation
import Observation
import UIKit

/// 和訳モデル（PLaMo 3 Translate 0.8B）を Hugging Face からダウンロードして端末に保存する。
/// ダウンロードはバックグラウンドの URLSession で行うので、アプリを閉じても続き、
/// 完了の知らせはアプリの再起動時やシステムによるバックグラウンド起動時に受け取る。
/// ハッシュが一致したファイルだけをモデルとして置くので、ファイルがあれば使える状態とみなす
@Observable
final class PlamoModelStore {
    enum State: Equatable {
        case notDownloaded
        /// progress は 0...1
        case downloading(progress: Double)
        /// ダウンロード後のファイル検査中
        case verifying
        case ready
        case failed(String)
    }

    /// 取得するファイル（リビジョンを固定し、ハッシュで照合する）
    nonisolated struct Remote: Sendable {
        let url: URL
        let sha256: String
        let size: Int64

        static let plamo3Translate = Remote(
            url: URL(string: "https://huggingface.co/pfnet/plamo-3-translate-0.8b-GGUF/resolve/03891e907db8a43c97d3a7c75add125cc6d1f96a/plamo-3-translate-0.8b-Q4_K_M.gguf")!,
            sha256: "3dbb09295bfd3350231ba0dba92bc72cb14111ef1b034e37dad39d581bd86b9c",
            size: 573_116_288
        )
    }

    /// 保存先（Application Support/PLaMo）。iCloud バックアップには含めない
    nonisolated static let defaultFileURL = URL.applicationSupportDirectory
        .appending(path: "PLaMo", directoryHint: .isDirectory)
        .appending(path: "\(PlamoTranslator.modelName).gguf")

    private(set) var state: State
    let remote: Remote
    let fileURL: URL
    private let downloader: any ModelDownloading
    private let availableCapacity: @Sendable (URL) -> Int64?
    /// ダウンロードが終わって検査待ちのファイル
    private var pendingURL: URL { downloader.destination }

    init(
        remote: Remote = .plamo3Translate,
        fileURL: URL = PlamoModelStore.defaultFileURL,
        downloader: (any ModelDownloading)? = nil,
        availableCapacity: @escaping @Sendable (URL) -> Int64? = { PlamoModelStore.volumeCapacity(at: $0) }
    ) {
        self.remote = remote
        self.fileURL = fileURL
        self.downloader = downloader ?? BackgroundModelDownloader.shared
        self.availableCapacity = availableCapacity
        state = FileManager.default.fileExists(atPath: fileURL.path) ? .ready : .notDownloaded

        self.downloader.setEventHandler { [weak self] event in
            Task { @MainActor in self?.handle(event) }
        }
        restore()
    }

    var isReady: Bool { state == .ready }

    var isBusy: Bool {
        switch state {
        case .downloading, .verifying: true
        default: false
        }
    }

    /// 表示用のサイズ（例: 573 MB）
    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: remote.size, countStyle: .file)
    }

    func download() {
        guard !isBusy, !isReady else { return }
        let directory = fileURL.deletingLastPathComponent()
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        } catch {
            state = .failed("保存先を用意できませんでした")
            return
        }
        // ダウンロード中の一時ファイルとモデル本体が同時に置かれるので、少し余裕を見る
        if let capacity = availableCapacity(directory), capacity < remote.size * 2 {
            state = .failed("空き容量が足りません（\(sizeText)の2倍ほど必要です）")
            return
        }
        state = .downloading(progress: 0)
        downloader.start(from: remote.url)
    }

    func cancel() {
        downloader.cancel()
        state = .notDownloaded
    }

    func delete() {
        downloader.cancel()
        try? FileManager.default.removeItem(at: fileURL)
        try? FileManager.default.removeItem(at: pendingURL)
        state = .notDownloaded
    }

    /// 前回の起動中に始めたダウンロードの続きを反映する
    private func restore() {
        guard !isReady else { return }
        if FileManager.default.fileExists(atPath: pendingURL.path) {
            verifyPendingFile()
            return
        }
        Task {
            guard let progress = await downloader.activeDownloadProgress(), state == .notDownloaded else { return }
            state = .downloading(progress: progress)
        }
    }

    private func handle(_ event: ModelDownloadEvent) {
        switch event {
        case .progress(let progress):
            guard case .downloading = state else { return }
            state = .downloading(progress: progress)
        case .finished:
            verifyPendingFile()
        case .cancelled:
            if case .downloading = state { state = .notDownloaded }
        case .failed:
            state = .failed("ダウンロードできませんでした。通信環境を確認して、もう一度お試しください")
        }
    }

    private func verifyPendingFile() {
        guard state != .verifying else { return }
        state = .verifying
        let pendingURL = pendingURL
        let fileURL = fileURL
        let sha256 = remote.sha256
        // ダウンロード完了でアプリが裏で起こされたときも、検査（数秒）を終えるまで止められないようにする
        let backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "PLaMo model verification")
        Task {
            defer { UIApplication.shared.endBackgroundTask(backgroundTask) }
            let isValid = await Task.detached(priority: .utility) {
                (try? Self.sha256(of: pendingURL)) == sha256
            }.value
            guard isValid else {
                try? FileManager.default.removeItem(at: pendingURL)
                state = .failed("ダウンロードしたファイルが壊れています。もう一度お試しください")
                return
            }
            do {
                try? FileManager.default.removeItem(at: fileURL)
                try FileManager.default.moveItem(at: pendingURL, to: fileURL)
                var resourceURL = fileURL
                var values = URLResourceValues()
                values.isExcludedFromBackup = true
                try? resourceURL.setResourceValues(values)
                state = .ready
            } catch {
                state = .failed("和訳モデルを保存できませんでした")
            }
        }
    }

    nonisolated static func sha256(of url: URL) throws -> String {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        var hasher = SHA256()
        while let chunk = try handle.read(upToCount: 4 * 1024 * 1024), !chunk.isEmpty {
            hasher.update(data: chunk)
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    nonisolated static func volumeCapacity(at url: URL) -> Int64? {
        try? url.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey]).volumeAvailableCapacityForImportantUsage
    }
}

nonisolated enum ModelDownloadEvent: Sendable {
    case progress(Double)
    /// destination にファイルを置いた
    case finished
    case cancelled
    case failed
}

/// ダウンロードを始め、進み具合や完了を知らせる（バックグラウンド URLSession 実装とテスト用 Fake を差し替える）
nonisolated protocol ModelDownloading: AnyObject, Sendable {
    /// ダウンロードが終わったファイルを置く場所
    var destination: URL { get }
    func setEventHandler(_ handler: @escaping @Sendable (ModelDownloadEvent) -> Void)
    func start(from url: URL)
    func cancel()
    /// 実行中のダウンロードがあればその進み具合（アプリの再起動後に表示を戻すため）
    func activeDownloadProgress() async -> Double?
}

/// バックグラウンドの URLSession でダウンロードする。アプリを閉じても OS が続け、
/// 終わるとアプリをバックグラウンドで起こして知らせる（AppDelegate が completionHandler を渡す）
nonisolated final class BackgroundModelDownloader: NSObject, ModelDownloading, URLSessionDownloadDelegate, @unchecked Sendable {
    static let sessionIdentifier = "\(Bundle.main.bundleIdentifier ?? "Tangomiru").plamo-model-download"
    static let shared = BackgroundModelDownloader(
        destination: PlamoModelStore.defaultFileURL.appendingPathExtension("download")
    )

    /// アプリのフォルダの場所はアップデートで変わることがあるので、絶対パスをタスクに持たせず毎回ここから求める
    let destination: URL
    private let lock = NSLock()
    private var eventHandler: (@Sendable (ModelDownloadEvent) -> Void)?
    private var _backgroundCompletionHandler: (@Sendable () -> Void)?
    private var _session: URLSession?

    /// システムがアプリを起こしたときに渡される。すべての知らせを受け取ったら呼ぶ
    var backgroundCompletionHandler: (@Sendable () -> Void)? {
        get { lock.withLock { _backgroundCompletionHandler } }
        set { lock.withLock { _backgroundCompletionHandler = newValue } }
    }

    init(destination: URL) {
        self.destination = destination
    }

    private var session: URLSession {
        lock.withLock {
            if let _session { return _session }
            let configuration = URLSessionConfiguration.background(withIdentifier: Self.sessionIdentifier)
            configuration.isDiscretionary = false
            configuration.sessionSendsLaunchEvents = true
            let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
            _session = session
            return session
        }
    }

    /// 起動時に呼び、前回の起動中に始めたダウンロードの知らせを受け取れるようにする
    func reconnect() {
        _ = session
    }

    func setEventHandler(_ handler: @escaping @Sendable (ModelDownloadEvent) -> Void) {
        lock.withLock { eventHandler = handler }
        reconnect()
    }

    private func send(_ event: ModelDownloadEvent) {
        lock.withLock { eventHandler }?(event)
    }

    func start(from url: URL) {
        let session = session
        session.getAllTasks { tasks in
            // すでに続きを進めているなら新しく始めない
            guard !tasks.contains(where: { $0.state == .running }) else { return }
            session.downloadTask(with: url).resume()
        }
    }

    func cancel() {
        session.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
    }

    func activeDownloadProgress() async -> Double? {
        let tasks = await session.allTasks
        guard let task = tasks.first(where: { $0.state == .running }) else { return nil }
        guard task.countOfBytesExpectedToReceive > 0 else { return 0 }
        return Double(task.countOfBytesReceived) / Double(task.countOfBytesExpectedToReceive)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        send(.progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        guard let response = downloadTask.response as? HTTPURLResponse, (200..<300).contains(response.statusCode) else {
            send(.failed)
            return
        }
        // location はこのメソッドを抜けると消えるので、すぐに移す
        do {
            try FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? FileManager.default.removeItem(at: destination)
            try FileManager.default.moveItem(at: location, to: destination)
            send(.finished)
        } catch {
            send(.failed)
        }
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        if (error as? URLError)?.code == .cancelled {
            send(.cancelled)
        } else {
            send(.failed)
        }
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        let handler = lock.withLock {
            defer { _backgroundCompletionHandler = nil }
            return _backgroundCompletionHandler
        }
        guard let handler else { return }
        DispatchQueue.main.async { handler() }
    }
}
