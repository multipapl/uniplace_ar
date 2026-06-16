//
//  UP_ARApp.swift
//  UP_AR (UniPlace)
//
//  Thin entry point. All real work lives in the App/, Screens/, AR/, Navigation/,
//  Content/, HUD/ and Diagnostics/ modules — see docs/Founding Brief.md.
//

import SwiftUI

@main
struct UP_ARApp: App {
    @State private var appModel = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appModel)
                .onAppear {
                    TimingDiagnostics.log("root view appeared")
                }
        }
    }
}
