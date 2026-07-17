//
//  KeyCombination.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import CoreGraphics

/// Represents one physical keyboard key together with its modifiers.
///
/// Examples:
/// - V
/// - Command + V
/// - Control + Option + N
nonisolated struct KeyCombination:
    Codable,
    Equatable,
    Hashable
{
    let keyCode: CGKeyCode
    let modifiers: KeyModifiers

    init(
        keyCode: CGKeyCode,
        modifiers: KeyModifiers = []
    ) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }
}
