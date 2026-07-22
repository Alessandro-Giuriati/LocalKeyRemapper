//
//  KeyCombinationConfigurationWarningPolicy.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/21/26.
//

import Carbon.HIToolbox
import CoreGraphics

/// Represents non-blocking guidance for a configured key combination.
nonisolated enum KeyCombinationConfigurationWarning:
    Equatable
{
    /// Fn is combined with one of the standard F1 through F12 keys.
    case fnWithFunctionKey

    var message:
        String
    {
        switch self {
        case .fnWithFunctionKey:
            return "Fn combined with a function key may be handled by macOS or the keyboard as a system or media action. This combination may not work consistently on every keyboard."
        }
    }
}

/// Applies shared, deterministic warning rules to configured key combinations.
///
/// This policy examines only explicitly configured combinations. It does not
/// monitor, record, persist, or log keyboard input.
nonisolated enum KeyCombinationConfigurationWarningPolicy {

    /// Returns informational guidance for one combination when needed.
    ///
    /// The warning never makes the combination invalid and never prevents
    /// rules, exceptions, or global shortcuts from being saved.
    static func warning(
        for combination:
            KeyCombination
    ) -> KeyCombinationConfigurationWarning? {
        guard
            combination
                .modifiers
                .contains(
                    .fn
                ),
            isStandardFunctionKey(
                combination.keyCode
            )
        else {
            return nil
        }

        return .fnWithFunctionKey
    }

    /// Returns the first warning contained in a remapping rule.
    ///
    /// Source, destination, and every stored exception are inspected so the
    /// same guidance is used throughout the complete rule editor.
    static func warning(
        for rule:
            RemapRule
    ) -> KeyCombinationConfigurationWarning? {
        if let warning = warning(
            for:
                rule.source
        ) {
            return warning
        }

        if let warning = warning(
            for:
                rule.destination
        ) {
            return warning
        }

        return warning(
            for:
                rule.overrides
        )
    }

    /// Returns the first warning contained in a stored exception.
    static func warning(
        for remapOverride:
            RemapOverride
    ) -> KeyCombinationConfigurationWarning? {
        if let warning = warning(
            for:
                remapOverride.source
        ) {
            return warning
        }

        guard
            case .replaceWith(
                let destination
            ) = remapOverride.action
        else {
            return nil
        }

        return warning(
            for:
                destination
        )
    }

    /// Returns the first warning found in a complete rule collection.
    static func warning(
        for rules:
            [RemapRule]
    ) -> KeyCombinationConfigurationWarning? {
        for rule in rules {
            if let warning = warning(
                for:
                    rule
            ) {
                return warning
            }
        }

        return nil
    }

    /// Returns the first warning found in a stored exception collection.
    static func warning(
        for overrides:
            [RemapOverride]
    ) -> KeyCombinationConfigurationWarning? {
        for remapOverride in overrides {
            if let warning = warning(
                for:
                    remapOverride
            ) {
                return warning
            }
        }

        return nil
    }

    /// Returns whether the key code represents F1 through F12.
    static func isStandardFunctionKey(
        _ keyCode:
            CGKeyCode
    ) -> Bool {
        standardFunctionKeyCodes
            .contains(
                keyCode
            )
    }

    private static let standardFunctionKeyCodes:
        Set<CGKeyCode> =
    [
        CGKeyCode(
            kVK_F1
        ),
        CGKeyCode(
            kVK_F2
        ),
        CGKeyCode(
            kVK_F3
        ),
        CGKeyCode(
            kVK_F4
        ),
        CGKeyCode(
            kVK_F5
        ),
        CGKeyCode(
            kVK_F6
        ),
        CGKeyCode(
            kVK_F7
        ),
        CGKeyCode(
            kVK_F8
        ),
        CGKeyCode(
            kVK_F9
        ),
        CGKeyCode(
            kVK_F10
        ),
        CGKeyCode(
            kVK_F11
        ),
        CGKeyCode(
            kVK_F12
        )
    ]
}
