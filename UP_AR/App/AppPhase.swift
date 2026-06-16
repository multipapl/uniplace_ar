//
//  AppPhase.swift
//  UP_AR (UniPlace)
//
//  High-level flow of the experience, mirroring the Founding Brief: start → calibrate → placed.
//

/// The three states of the Phase 1 core loop.
enum AppPhase {
    /// UniPlace start screen with a single entry button.
    case start
    /// Aiming the device at the floor to set the origin / camera height.
    case calibrating
    /// Scene anchored on the floor; physical walking, teleport and reset are active.
    case placed
}
