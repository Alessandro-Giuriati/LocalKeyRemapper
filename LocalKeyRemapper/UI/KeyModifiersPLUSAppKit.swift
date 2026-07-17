//
//  KeyModifiersPLUSAppKit.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import AppKit

extension KeyModifiers {

    /// Converts the AppKit modifiers captured by the Settings interface
    /// into the normalized modifiers used by the remapping backend.
    init(appKitFlags: NSEvent.ModifierFlags) {
        var modifiers: KeyModifiers = []

        if appKitFlags.contains(.shift) {
            modifiers.insert(.shift)
        }

        if appKitFlags.contains(.control) {
            modifiers.insert(.control)
        }

        if appKitFlags.contains(.option) {
            modifiers.insert(.option)
        }

        if appKitFlags.contains(.command) {
            modifiers.insert(.command)
        }

        self = modifiers
    }
}

