//
//  TimingDiagnostics.swift
//  UP_AR (UniPlace)
//
//  Tiny stopwatch logs for cold-start and AR-session latency checks.
//

import Foundation

enum TimingDiagnostics {
    private static let launchTime = CFAbsoluteTimeGetCurrent()

    static func log(_ label: String) {
        let elapsed = CFAbsoluteTimeGetCurrent() - launchTime
        print(String(format: "UniPlace timing | %@ | +%.3fs", label, elapsed))
    }
}
