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
    @State private var services = AppServices()

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(services)
                .task { await services.load() }
                .task {
                    await AdConsent.prepare()
                    services.extractionAd.preload()
                }
        }
        .modelContainer(for: [Passage.self, CustomSource.self])
    }
}
