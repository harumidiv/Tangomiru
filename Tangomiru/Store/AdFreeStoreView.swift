import StoreKit
import SwiftUI

/// 広告なしプランの購入画面。価格・購入・復元・解約の管理は Apple の画面に任せる
/// 閉じるボタンは他の画面に合わせてナビゲーションバーの「完了」にし、Apple の × は出さない。
/// Mac では StoreKit が画面を表示し直してアプリの environment が届かないことがあるため、必要なものは引数で受け取る
struct AdFreeStoreView: View {
    let purchases: PurchaseManager
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            storeView
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("完了", action: onClose)
                    }
                }
        }
    }

    private var storeView: some View {
        SubscriptionStoreView(productIDs: [StoreConfig.adFreeProductID]) {
            VStack(spacing: 12) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.orange)
                Text("広告なしプラン")
                    .font(.title.bold())
                Text(purchases.isAdFree
                     ? "ご利用ありがとうございます。広告は表示されません"
                     : "英文の取り込み中やクイズの後に表示される広告が、すべて表示されなくなります")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .storeButton(.visible, for: .restorePurchases)
        .storeButton(.hidden, for: .cancellation)
        .subscriptionStorePolicyDestination(url: StoreConfig.privacyPolicyURL, for: .privacyPolicy)
        .subscriptionStorePolicyDestination(url: StoreConfig.termsOfServiceURL, for: .termsOfService)
        .onInAppPurchaseCompletion { _, _ in
            await purchases.refresh()
        }
    }
}
