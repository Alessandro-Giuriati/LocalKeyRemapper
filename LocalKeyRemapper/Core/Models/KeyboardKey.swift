//
//  KeyboardKey.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import CoreGraphics

/// Represents a keyboard key that can be displayed
/// and selected in the application interface.
nonisolated struct KeyboardKey: Hashable, Sendable {

    /// Physical virtual key code used by macOS.
    let keyCode: CGKeyCode

    /// Human-readable name displayed in the interface.
    let displayName: String
}
