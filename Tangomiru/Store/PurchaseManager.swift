import Foundation
import Observation
import StoreKit

/// 広告なしプランの購入状態。起動時に確認し、購入・更新・解約・返金を待ち受けて反映する
@Observable
final class PurchaseManager {
    private(set) var isAdFree = false
    private var updatesTask: Task<Void, Never>?

    /// 購入状態を確認し、以降の変化の待ち受けを始める
    func start() async {
        if updatesTask == nil {
            updatesTask = Task {
                for await result in Transaction.updates {
                    if case .verified(let transaction) = result { await transaction.finish() }
                    await refresh()
                }
            }
        }
        await refresh()
    }

    func refresh() async {
        var entitlements: [AdFreeEntitlement] = []
        // 署名を検証できた購入だけを信用する
        for await result in Transaction.currentEntitlements {
            guard case .verified(let transaction) = result else { continue }
            entitlements.append(AdFreeEntitlement(
                productID: transaction.productID,
                expirationDate: transaction.expirationDate,
                revocationDate: transaction.revocationDate
            ))
        }
        isAdFree = AdFreeStatus.isAdFree(entitlements, now: .now)
    }
}
