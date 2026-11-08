import CryptoKit
import Foundation
import Testing
@testable import Tangomiru

/// 通信の代わりに、start で指定した内容を destination に書いて完了を知らせる
nonisolated final class FakeModelDownloader: ModelDownloading, @unchecked Sendable {
    let destination: URL
    var contents = Data("model".utf8)
    var fails = false
    var activeProgress: Double?
    private(set) var startCount = 0
    private var handler: (@Sendable (ModelDownloadEvent) -> Void)?

    init(destination: URL) {
        self.destination = destination
    }

    func setEventHandler(_ handler: @escaping @Sendable (ModelDownloadEvent) -> Void) {
        self.handler = handler
    }

    func start(from url: URL) {
        startCount += 1
        if fails {
            handler?(.failed)
            return
        }
        handler?(.progress(0.5))
        try? FileManager.default.createDirectory(at: destination.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? contents.write(to: destination)
        handler?(.finished)
    }

    func cancel() {
        handler?(.cancelled)
    }

    func activeDownloadProgress() async -> Double? {
        activeProgress
    }
}

extension PlamoModelStore {
    /// ダウンロード・検査が落ち着くまで待つ（知らせは MainActor のタスクで届くため）
    func settle() async {
        for _ in 0..<500 {
            await Task.yield()
            try? await Task.sleep(for: .milliseconds(5))
            if !isBusy { return }
        }
    }
}

struct PlamoModelStoreTests {
    private let directory = FileManager.default.temporaryDirectory.appending(path: "PlamoModelStoreTests-\(UUID().uuidString)")
    private var fileURL: URL { directory.appending(path: "model.gguf") }

    private static func sha256(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private func makeDownloader() -> FakeModelDownloader {
        FakeModelDownloader(destination: fileURL.appendingPathExtension("download"))
    }

    private func store(
        downloader: FakeModelDownloader? = nil,
        sha256: String = PlamoModelStoreTests.sha256(Data("model".utf8)),
        capacity: Int64? = 1_000_000
    ) -> PlamoModelStore {
        PlamoModelStore(
            remote: .init(url: URL(string: "https://example.com/model.gguf")!, sha256: sha256, size: 5),
            fileURL: fileURL,
            downloader: downloader ?? makeDownloader(),
            availableCapacity: { _ in capacity }
        )
    }

    @Test func startsNotDownloadedWithoutFile() {
        #expect(store().state == .notDownloaded)
    }

    @Test func downloadVerifiesAndSavesFile() async throws {
        let store = store()
        store.download()
        await store.settle()
        #expect(store.state == .ready)
        #expect(try Data(contentsOf: fileURL) == Data("model".utf8))
        #expect(try fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup == true)
        // 次に起動したときはダウンロード済みとして始まる
        #expect(self.store().state == .ready)
    }

    @Test func rejectsFileWithWrongHash() async {
        let store = store(sha256: String(repeating: "0", count: 64))
        store.download()
        await store.settle()
        guard case .failed = store.state else {
            Issue.record("失敗になっていない: \(store.state)")
            return
        }
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func failsWithoutEnoughSpace() async {
        let store = store(capacity: 9)
        store.download()
        await store.settle()
        guard case .failed(let message) = store.state else {
            Issue.record("失敗になっていない: \(store.state)")
            return
        }
        #expect(message.contains("空き容量"))
    }

    @Test func failsWhenDownloadFails() async {
        let downloader = makeDownloader()
        downloader.fails = true
        let store = store(downloader: downloader)
        store.download()
        await store.settle()
        guard case .failed = store.state else {
            Issue.record("失敗になっていない: \(store.state)")
            return
        }
    }

    @Test func deleteRemovesFile() async {
        let store = store()
        store.download()
        await store.settle()
        store.delete()
        #expect(store.state == .notDownloaded)
        #expect(!FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test func translatorBecomesAvailableAfterDownload() async {
        let translator = PlamoTranslator(modelURL: fileURL)
        #expect(!translator.isAvailable)
        let store = store()
        store.download()
        await store.settle()
        #expect(translator.isAvailable)
    }

    @Test func verifiesFileFinishedWhileAppWasNotRunning() async throws {
        // 前回の起動中に終わり、検査前のファイルだけが残っている
        let downloader = makeDownloader()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("model".utf8).write(to: downloader.destination)
        let store = store(downloader: downloader)
        await store.settle()
        #expect(store.state == .ready)
        #expect(downloader.startCount == 0)
        #expect(!FileManager.default.fileExists(atPath: downloader.destination.path))
    }

    @Test func restoresProgressOfDownloadStartedEarlier() async {
        let downloader = makeDownloader()
        downloader.activeProgress = 0.4
        let store = store(downloader: downloader)
        for _ in 0..<100 where store.state == .notDownloaded { try? await Task.sleep(for: .milliseconds(5)) }
        #expect(store.state == .downloading(progress: 0.4))
    }
}
