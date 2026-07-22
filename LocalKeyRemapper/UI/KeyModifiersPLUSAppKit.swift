//
//  KeyModifiersPLUSAppKit.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import AppKit

extension KeyModifiers {

    /// Converts only ordinary AppKit modifier flags into the normalized
    /// modifiers used by the remapping backend.
    ///
    /// AppKit's `.function` flag identifies function-key input and is also
    /// present on keys such as F1-F12 and navigation keys. It must therefore
    /// not be interpreted as proof that the physical Fn key is held.
    init(
        appKitFlags:
            NSEvent.ModifierFlags
    ) {
        var modifiers:
            KeyModifiers = []

        if appKitFlags.contains(
            .shift
        ) {
            modifiers.insert(
                .shift
            )
        }

        if appKitFlags.contains(
            .control
        ) {
            modifiers.insert(
                .control
            )
        }

        if appKitFlags.contains(
            .option
        ) {
            modifiers.insert(
                .option
            )
        }

        if appKitFlags.contains(
            .command
        ) {
            modifiers.insert(
                .command
            )
        }

        self = modifiers
    }
}
