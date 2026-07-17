//
//  RemapDecision.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import CoreGraphics

/// Represents the decision made by the remapping engine
/// for a specific keyboard event.
nonisolated enum RemapDecision:
    Equatable
{
    /// The keyboard event must remain unchanged.
    case passThrough

    /// The source must be replaced by a complete key combination.
    case replaceWith(KeyCombination)

    /// Compatibility helper for tests and code that only work with
    /// unmodified key codes.
    static func replaceKeyCode(
        _ keyCode: CGKeyCode
    ) -> RemapDecision {
        .replaceWith(
            KeyCombination(
                keyCode: keyCode
            )
        )
    }
}
