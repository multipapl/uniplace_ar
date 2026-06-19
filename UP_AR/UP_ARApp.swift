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
            // Developer preview harness (see __SnapshotHarness.swift / Tools/snapshot.sh).
            // Never set in production, so the real app path is unaffected.
            if let snapshot = ProcessInfo.processInfo.environment["UP_SNAPSHOT_VIEW"] {
                SnapshotHarness.liveView(named: snapshot)
            } else {
                RootView()
                    .environment(appModel)
                    .onAppear {
                        TimingDiagnostics.log("root view appeared")
                    }
            }
        }
    }
}
