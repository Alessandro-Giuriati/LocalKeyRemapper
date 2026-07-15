//
//  KeyCode.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import Carbon.HIToolbox
import CoreGraphics

/// Physical key codes used by the application.
///
/// Readable names such as `.v` and `.w` prevent unexplained
/// numeric values from being scattered throughout the project.
nonisolated enum KeyCode {

    static let v = CGKeyCode(kVK_ANSI_V)
    static let w = CGKeyCode(kVK_ANSI_W)
}
