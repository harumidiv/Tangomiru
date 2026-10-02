import Foundation

/// 広告なしプラン（月額）の商品と、購入画面に出すリンク
enum StoreConfig {
    static let adFreeProductID = "harumidiv.Tangomiru.adFree.monthly"
    static let privacyPolicyURL = URL(string: "https://harumidiv.github.io/AppleStoreDevelopprSite/privacy-tangomiru.html")!
    /// Apple の標準利用規約（EULA）
    static let termsOfServiceURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
}
