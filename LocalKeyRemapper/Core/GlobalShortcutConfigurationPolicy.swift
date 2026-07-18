//
//  GlobalShortcutConfigurationPolicy.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/18/26.
//

/// Represents an invalid application shortcut configuration.
nonisolated enum GlobalShortcutConfigurationError:
    Error,
    Equatable
{
    /// Two application commands use the same key combination.
    case duplicateShortcut

    /// A global shortcut does not contain any modifier and
    /// would interfere with normal typing.
    case insufficientModifiers(
        GlobalShortcutAction
    )
}

/// Represents non-blocking guidance for a valid shortcut configuration.
nonisolated enum GlobalShortcutConfigurationSuggestion:
    Equatable
{
    /// At least one shortcut uses exactly one modifier.
    case useAdditionalModifier

    var message:
        String
    {
        switch self {
        case .useAdditionalModifier:
            return "Using only one modifier may conflict with shortcuts in other applications. Two or more modifiers are recommended."
        }
    }
}

/// Applies deterministic validation and guidance rules to global shortcuts.
///
/// This policy does not inspect keyboard input and does not assume that
/// macOS uses its default shortcuts. Real availability is verified later
/// by attempting registration with the operating system.
nonisolated enum GlobalShortcutConfigurationPolicy {

    /// Rejects only configurations that are internally unsafe or ambiguous.
    static func validate(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        var seenShortcuts:
            Set<KeyCombination> = []

        for registration in
            configuration.registrations
        {
            guard
                registration
                    .shortcut
                    .modifiers
                    .rawValue
                    .nonzeroBitCount
                    >= 1
            else {
                throw GlobalShortcutConfigurationError
                    .insufficientModifiers(
                        registration.action
                    )
            }

            guard
                seenShortcuts
                    .insert(
                        registration.shortcut
                    )
                    .inserted
            else {
                throw GlobalShortcutConfigurationError
                    .duplicateShortcut
            }
        }
    }

    /// Returns non-blocking guidance for a valid configuration.
    static func suggestion(
        for configuration:
            RemappingShortcutConfiguration
    ) -> GlobalShortcutConfigurationSuggestion? {
        let usesOneModifier =
            configuration
                .registrations
                .contains {
                    registration in

                    registration
                        .shortcut
                        .modifiers
                        .rawValue
                        .nonzeroBitCount
                        == 1
                }

        return usesOneModifier
            ? .useAdditionalModifier
            : nil
    }
}
