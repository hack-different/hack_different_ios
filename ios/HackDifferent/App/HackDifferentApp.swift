//
//  HackDifferentApp.swift
//  HackDifferent
//

import AudienceKit
import AudienceKitUI
import SwiftUI

@main
struct HackDifferentApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .audiencePreset(appModel.brand.preset)
                .audienceUpdatePrompts()
                .task {
                    await appModel.start()
                }
        }
    }
}
