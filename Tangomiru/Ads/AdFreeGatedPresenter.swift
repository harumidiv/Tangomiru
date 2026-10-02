/// 広告なしプランの間は、包んだ広告の読み込みも表示もしない
final class AdFreeGatedPresenter: InterstitialAdPresenting {
    private let base: any InterstitialAdPresenting
    private let isAdFree: () -> Bool

    init(base: any InterstitialAdPresenting, isAdFree: @escaping () -> Bool) {
        self.base = base
        self.isAdFree = isAdFree
    }

    func preload() {
        guard !isAdFree() else { return }
        base.preload()
    }

    func presentIfReady() async {
        guard !isAdFree() else { return }
        await base.presentIfReady()
    }
}
