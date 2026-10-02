import GoogleMobileAds

/// AdMob のインタースティシャル広告。1本ずつ読み込み、表示したら使い切る
final class GoogleInterstitialAdPresenter: NSObject, InterstitialAdPresenting, FullScreenContentDelegate {
    private let adUnitID: String
    private var ad: InterstitialAd?
    private var isLoading = false
    private var dismissal: CheckedContinuation<Void, Never>?

    init(adUnitID: String = AdConfig.extractionInterstitialUnitID) {
        self.adUnitID = adUnitID
    }

    func preload() {
        // 同意が取れていない地域では広告をリクエストしない
        guard ad == nil, !isLoading, AdConsent.canRequestAds else { return }
        isLoading = true
        Task {
            defer { isLoading = false }
            ad = try? await InterstitialAd.load(with: adUnitID, request: Request())
            ad?.fullScreenContentDelegate = self
        }
    }

    func presentIfReady() async {
        guard let ad else { return }
        self.ad = nil
        await withCheckedContinuation { continuation in
            dismissal = continuation
            ad.present(from: nil)
        }
    }

    func adDidDismissFullScreenContent(_ ad: any FullScreenPresentingAd) {
        finishPresenting()
    }

    func ad(_ ad: any FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: any Error) {
        finishPresenting()
    }

    private func finishPresenting() {
        dismissal?.resume()
        dismissal = nil
    }
}
