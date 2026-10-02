/// 全画面広告の読み込みと表示（テストでは偽物に差し替える）
protocol InterstitialAdPresenting: AnyObject {
    /// 次に表示する広告を読み込んでおく（読み込み済みなら何もしない）
    func preload()
    /// 読み込み済みなら表示して閉じられるまで待つ。無ければすぐ戻る
    func presentIfReady() async
}
