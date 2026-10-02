/// AdMob の広告ユニット ID。アプリ ID はビルド設定 GAD_APPLICATION_IDENTIFIER（Info.plist 経由）
enum AdConfig {
    #if DEBUG
    /// 開発中に本番広告を表示・タップすると AdMob アカウントが止められるため、Google のテスト用 ID を使う
    static let extractionInterstitialUnitID = "ca-app-pub-3940256099942544/4411468910"
    #else
    static let extractionInterstitialUnitID = "ca-app-pub-8522231452310619/7388118501"
    #endif
}
