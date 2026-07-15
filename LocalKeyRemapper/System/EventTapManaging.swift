//
//  EventTapManaging.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

/// Defines the lifecycle operations required
/// by a keyboard event tap manager.
@MainActor
protocol EventTapManaging: AnyObject {

    /// Indicates whether the event tap is currently installed.
    var isRunning: Bool { get }

    /// Creates and installs the keyboard event tap.
    func start() throws

    /// Disables and completely removes the keyboard event tap.
    func stop()
}
