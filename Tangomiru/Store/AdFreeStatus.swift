import Foundation

/// StoreKit の Transaction から、判定に必要な項目だけを抜き出したもの
nonisolated struct AdFreeEntitlement: Sendable {
    let productID: String
    let expirationDate: Date?
    let revocationDate: Date?
}

nonisolated enum AdFreeStatus {
    /// 広告なしプランが有効なら true（返金済み・期限切れ・別の商品は対象外）
    static func isAdFree(_ entitlements: [AdFreeEntitlement], now: Date) -> Bool {
        entitlements.contains { entitlement in
            guard entitlement.productID == StoreConfig.adFreeProductID, entitlement.revocationDate == nil else { return false }
            return entitlement.expirationDate.map { $0 > now } ?? true
        }
    }
}
