//
//  AppPhase.swift
//  UP_AR (UniPlace)
//
//  High-level flow of the experience, mirroring the Founding Brief: start → calibrate → placed.
//

/// The states of the core loop.
enum AppPhase {
    /// UniPlace start screen with the scene picker.
    case start
    /// Aiming the device at the floor to set the origin / camera height.
    case calibrating
    /// Floor confirmed; the chosen scene is being fully loaded behind a loading screen. Nothing of the
    /// scene is shown until it is completely ready (no half-built pop-in).
    case loading
    /// Scene anchored on the floor; physical walking, teleport and reset are active.
    case placed
}
