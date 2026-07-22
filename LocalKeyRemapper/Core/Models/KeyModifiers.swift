//
//  KeyModifiers.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import CoreGraphics

/// Represents the keyboard modifiers supported by remapping rules.
///
/// Shift, Control, Option, Command, and Fn are represented explicitly.
/// Other Core Graphics event flags remain untouched when a remapping
/// changes the supported modifiers.
nonisolated struct KeyModifiers:
    OptionSet,
    Codable,
    Hashable
{
    let rawValue: UInt8

    static let shift = KeyModifiers(
        rawValue: 1 << 0
    )

    static let control = KeyModifiers(
        rawValue: 1 << 1
    )

    static let option = KeyModifiers(
        rawValue: 1 << 2
    )

    static let command = KeyModifiers(
        rawValue: 1 << 3
    )

    static let fn = KeyModifiers(
        rawValue: 1 << 4
    )

    init(rawValue: UInt8) {
        self.rawValue = rawValue
    }

    /// Creates the normalized modifier value used by the remapping engine.
    init(eventFlags: CGEventFlags) {
        var modifiers: KeyModifiers = []

        if eventFlags.contains(.maskShift) {
            modifiers.insert(.shift)
        }

        if eventFlags.contains(.maskControl) {
            modifiers.insert(.control)
        }

        if eventFlags.contains(.maskAlternate) {
            modifiers.insert(.option)
        }

        if eventFlags.contains(.maskCommand) {
            modifiers.insert(.command)
        }

        if eventFlags.contains(.maskSecondaryFn) {
            modifiers.insert(.fn)
        }

        self = modifiers
    }

    /// Returns the Core Graphics flags represented by this value.
    var eventFlags: CGEventFlags {
        var flags: CGEventFlags = []

        if contains(.shift) {
            flags.insert(.maskShift)
        }

        if contains(.control) {
            flags.insert(.maskControl)
        }

        if contains(.option) {
            flags.insert(.maskAlternate)
        }

        if contains(.command) {
            flags.insert(.maskCommand)
        }

        if contains(.fn) {
            flags.insert(.maskSecondaryFn)
        }

        return flags
    }

    /// Replaces only the supported keyboard modifiers while preserving
    /// unrelated Core Graphics flags such as numeric-pad metadata.
    func applying(
        to existingFlags: CGEventFlags
    ) -> CGEventFlags {
        var updatedFlags = existingFlags

        updatedFlags.remove(.maskShift)
        updatedFlags.remove(.maskControl)
        updatedFlags.remove(.maskAlternate)
        updatedFlags.remove(.maskCommand)
        updatedFlags.remove(.maskSecondaryFn)

        updatedFlags.formUnion(eventFlags)

        return updatedFlags
    }
}
