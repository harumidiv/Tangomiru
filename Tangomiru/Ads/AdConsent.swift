import AppTrackingTransparency
import GoogleMobileAds
import UserMessagingPlatform

/// 起動時に、同意フォーム（必要な地域のみ）→ トラッキング許可 → AdMob の初期化の順で行う
enum AdConsent {
    static var canRequestAds: Bool { ConsentInformation.shared.canRequestAds }

    static func prepare() async {
        do {
            try await ConsentInformation.shared.requestConsentInfoUpdate(with: RequestParameters())
            try await ConsentForm.loadAndPresentIfRequired(from: nil)
        } catch {
            // 同意情報を取れなくても、前回までの同意があれば広告は出せる
        }
        // 許可されなくても、パーソナライズされない広告は出せる
        _ = await ATTrackingManager.requestTrackingAuthorization()
        guard canRequestAds else { return }
        await MobileAds.shared.start()
    }
}
