//
//  MemoryDiagnostics.swift
//  UP_AR (UniPlace)
//
//  Lightweight memory read-out (physical footprint) for the debug overlay and load logging.
//  Ported in spirit from the AVP app's MemoryDiagnostics. Memory is the hard limit on iPad Air 4,
//  so this is wired in from Phase 1 to measure early.
//

import Foundation

enum MemoryDiagnostics {
    /// Current physical memory footprint in bytes (matches Xcode's "Memory" gauge closely).
    static func footprintBytes() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : 0
    }

    static func footprintLabel() -> String {
        String(format: "%.0f MB", Double(footprintBytes()) / (1024 * 1024))
    }

    static func log(_ label: String) {
        print("UniPlace memory | \(label) | footprint=\(footprintLabel())")
    }
}
