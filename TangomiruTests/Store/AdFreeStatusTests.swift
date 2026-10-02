import Foundation
import Testing
@testable import Tangomiru

struct AdFreeStatusTests {
    private let now = Date(timeIntervalSince1970: 1_000_000)
    private let productID = StoreConfig.adFreeProductID

    @Test func activeSubscriptionRemovesAds() {
        let entitlement = AdFreeEntitlement(productID: productID, expirationDate: now.addingTimeInterval(60), revocationDate: nil)
        #expect(AdFreeStatus.isAdFree([entitlement], now: now))
    }

    @Test func expiredSubscriptionShowsAds() {
        let entitlement = AdFreeEntitlement(productID: productID, expirationDate: now.addingTimeInterval(-60), revocationDate: nil)
        #expect(!AdFreeStatus.isAdFree([entitlement], now: now))
    }

    @Test func refundedSubscriptionShowsAds() {
        let entitlement = AdFreeEntitlement(
            productID: productID, expirationDate: now.addingTimeInterval(60), revocationDate: now.addingTimeInterval(-1)
        )
        #expect(!AdFreeStatus.isAdFree([entitlement], now: now))
    }

    @Test func otherProductShowsAds() {
        let entitlement = AdFreeEntitlement(productID: "other", expirationDate: now.addingTimeInterval(60), revocationDate: nil)
        #expect(!AdFreeStatus.isAdFree([entitlement], now: now))
    }

    @Test func noEntitlementShowsAds() {
        #expect(!AdFreeStatus.isAdFree([], now: now))
    }
}
