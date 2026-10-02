/// 抽出の待ち時間に広告を出す。広告と抽出を同時に始め、両方が終わってから結果を返す
enum ExtractionWithAd {
    static func run<Value>(ad: any InterstitialAdPresenting, work: () async -> Value) async -> Value {
        async let adClosed: Void = ad.presentIfReady()
        let value = await work()
        await adClosed
        // 次の抽出に備えて、次の広告を読み込んでおく
        ad.preload()
        return value
    }
}
