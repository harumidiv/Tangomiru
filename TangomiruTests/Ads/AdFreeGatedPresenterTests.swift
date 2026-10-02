import Testing
@testable import Tangomiru

struct AdFreeGatedPresenterTests {
    @Test func adFreeSkipsLoadingAndShowing() async {
        let base = FakeAdPresenter()
        let gated = AdFreeGatedPresenter(base: base) { true }
        gated.preload()
        await gated.presentIfReady()
        #expect(base.preloadCount == 0)
        #expect(base.events.isEmpty)
    }

    @Test func withoutSubscriptionShowsAdsAsBefore() async {
        let base = FakeAdPresenter()
        let gated = AdFreeGatedPresenter(base: base) { false }
        gated.preload()
        await gated.presentIfReady()
        #expect(base.preloadCount == 1)
        #expect(base.events == ["ad-start", "ad-end"])
    }

    @Test func followsSubscriptionChanges() async {
        let base = FakeAdPresenter()
        var isAdFree = false
        let gated = AdFreeGatedPresenter(base: base) { isAdFree }
        isAdFree = true
        await gated.presentIfReady()
        #expect(base.events.isEmpty)
    }
}
