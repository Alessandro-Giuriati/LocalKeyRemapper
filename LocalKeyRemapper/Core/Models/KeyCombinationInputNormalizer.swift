//
//  KeyCombinationInputNormalizer.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/21/26.
//

import Carbon.HIToolbox
import CoreGraphics

/// Converts the key code delivered by macOS into the physical combination
/// the user intended to configure or match.
///
/// macOS may attach function-key metadata to ordinary F-keys and navigation
/// keys. It may also deliver Fn-navigation gestures as Home, End, Page Up,
/// Page Down, or Forward Delete. This normalizer keeps those details out of
/// the persistent remapping model.
nonisolated enum KeyCombinationInputNormalizer {

    static func combination(
        deliveredKeyCode:
            CGKeyCode,
        modifiers:
            KeyModifiers,
        physicalFnIsPressed:
            Bool
    ) -> KeyCombination {
        var normalizedModifiers =
            modifiers

        // Event-specific function metadata is not sufficient evidence that
        // the physical Fn key is down. The physical state is supplied
        // separately by PhysicalFnKeyState.
        normalizedModifiers.remove(
            .fn
        )

        let normalizedKeyCode:
            CGKeyCode

        if physicalFnIsPressed {
            normalizedModifiers.insert(
                .fn
            )

            normalizedKeyCode =
                physicalKeyCode(
                    forDeliveredKeyCode:
                        deliveredKeyCode
                )
        } else {
            normalizedKeyCode =
                deliveredKeyCode
        }

        return KeyCombination(
            keyCode:
                normalizedKeyCode,
            modifiers:
                normalizedModifiers
        )
    }

    /// Reverses the standard navigation transformations performed by macOS
    /// while the physical Fn key is held.
    private static func physicalKeyCode(
        forDeliveredKeyCode keyCode:
            CGKeyCode
    ) -> CGKeyCode {
        switch Int(keyCode) {
        case kVK_Home:
            return CGKeyCode(
                kVK_LeftArrow
            )

        case kVK_End:
            return CGKeyCode(
                kVK_RightArrow
            )

        case kVK_PageUp:
            return CGKeyCode(
                kVK_UpArrow
            )

        case kVK_PageDown:
            return CGKeyCode(
                kVK_DownArrow
            )

        case kVK_ForwardDelete:
            return CGKeyCode(
                kVK_Delete
            )

        default:
            return keyCode
        }
    }
}
