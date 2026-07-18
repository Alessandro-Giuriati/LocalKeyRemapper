//
//  KeyCombinationDisplayName.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

/// Converts complete key combinations into compact macOS-style names.
nonisolated enum KeyCombinationDisplayName {

    static func name(
        for combination:
            KeyCombination
    ) -> String {
        modifierPrefix(
            for:
                combination.modifiers
        ) + KeyboardLayoutKeyName.name(
            for:
                combination.keyCode
        )
    }

    static func modifierPrefix(
        for modifiers:
            KeyModifiers
    ) -> String {
        var result = ""

        if modifiers.contains(
            .control
        ) {
            result +=
                "⌃"
        }

        if modifiers.contains(
            .option
        ) {
            result +=
                "⌥"
        }

        if modifiers.contains(
            .shift
        ) {
            result +=
                "⇧"
        }

        if modifiers.contains(
            .command
        ) {
            result +=
                "⌘"
        }

        return result
    }
}
