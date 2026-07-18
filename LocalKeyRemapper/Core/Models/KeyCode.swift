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
/// Readable names prevent unexplained numeric values from being
/// scattered throughout the project.
nonisolated enum KeyCode {

    static let b =
        CGKeyCode(kVK_ANSI_B)

    static let j =
        CGKeyCode(kVK_ANSI_J)

    static let n =
        CGKeyCode(kVK_ANSI_N)
    
    static let r =
        CGKeyCode(kVK_ANSI_R)

    static let v =
        CGKeyCode(kVK_ANSI_V)

    static let w =
        CGKeyCode(kVK_ANSI_W)
}
