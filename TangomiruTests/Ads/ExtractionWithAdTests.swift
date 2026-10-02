import Testing
@testable import Tangomiru

/// 広告の表示と終了を記録する偽物。delay だけ表示したことにする
final class FakeAdPresenter: InterstitialAdPresenting {
    private(set) var events: [String] = []
    private(set) var preloadCount = 0
    let isReady: Bool
    let delay: Duration

    init(isReady: Bool = true, delay: Duration = .zero) {
        self.isReady = isReady
        self.delay = delay
    }

    func preload() { preloadCount += 1 }

    func presentIfReady() async {
        guard isReady else { return }
        events.append("ad-start")
        try? await Task.sleep(for: delay)
        events.append("ad-end")
    }
}

struct ExtractionWithAdTests {
    @Test func waitsForAdWhenWorkFinishesFirst() async {
        let ad = FakeAdPresenter(delay: .milliseconds(100))
        let value = await ExtractionWithAd.run(ad: ad) { 42 }
        #expect(value == 42)
        #expect(ad.events == ["ad-start", "ad-end"])
    }

    @Test func waitsForWorkWhenAdFinishesFirst() async {
        let ad = FakeAdPresenter()
        var workFinished = false
        let value = await ExtractionWithAd.run(ad: ad) {
            try? await Task.sleep(for: .milliseconds(100))
            workFinished = true
            return "done"
        }
        #expect(value == "done")
        #expect(workFinished)
        #expect(ad.events == ["ad-start", "ad-end"])
    }

    @Test func showsAdWhileWorkIsRunning() async {
        let ad = FakeAdPresenter(delay: .milliseconds(50))
        var eventsWhenWorkStarted: [String] = []
        _ = await ExtractionWithAd.run(ad: ad) {
            try? await Task.sleep(for: .milliseconds(10))
            eventsWhenWorkStarted = ad.events
            return 0
        }
        #expect(eventsWhenWorkStarted == ["ad-start"])
    }

    @Test func doesNotWaitWithoutAd() async {
        let ad = FakeAdPresenter(isReady: false)
        let value = await ExtractionWithAd.run(ad: ad) { 1 }
        #expect(value == 1)
        #expect(ad.events.isEmpty)
    }

    @Test func preloadsNextAdAfterRunning() async {
        let ad = FakeAdPresenter()
        _ = await ExtractionWithAd.run(ad: ad) { 0 }
        #expect(ad.preloadCount == 1)
    }
}
