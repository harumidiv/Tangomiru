//
//  TangomiruApp.swift
//  Tangomiru
//
//  Created by harumi.sagawa on 2026/09/30.
//

import SwiftData
import SwiftUI

@main
struct TangomiruApp: App {
    #if DEBUG
    @State private var services = AppServices(adsEnabled: !ScreenshotMode.isActive)
    #else
    @State private var services = AppServices()
    #endif

    var body: some Scene {
        WindowGroup {
            root
                .environment(services)
                .task { await services.load() }
                .task {
                    #if DEBUG
                    // 撮影モードでは同意フォーム・トラッキング許可を出さない
                    guard !ScreenshotMode.isActive else { return }
                    #endif
                    // 広告なしプランなら、広告のための同意・トラッキング許可も求めない
                    await services.purchases.start()
                    guard !services.purchases.isAdFree else { return }
                    await AdConsent.prepare()
                    services.extractionAd.preload()
                    services.quizResultAd.preload()
                }
        }
        .modelContainer(for: [Passage.self, CustomSource.self])
    }

    @ViewBuilder
    private var root: some View {
        #if DEBUG
        if let screen = ScreenshotMode.screen {
            ScreenshotRootView(screen: screen, samples: .shared)
                .modelContainer(ScreenshotSamples.shared.container)
        } else {
            LibraryView()
        }
        #else
        LibraryView()
        #endif
    }
}
