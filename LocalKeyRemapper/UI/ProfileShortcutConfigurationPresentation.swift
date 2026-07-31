//
//  ProfileShortcutConfigurationPresentation.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation

/// Identifies the shortcut mode selected in the profile shortcut editor.
///
/// `useDefault` remains separate from `off`:
///
/// - Use Default stores no override.
/// - Off stores an explicit `.disabled` override.
nonisolated enum ProfileShortcutConfigurationMode:
    Int,
    CaseIterable,
    Equatable
{
    case useDefault = 0
    case off = 1
    case toggle = 2
    case separate = 3
}

/// Represents either a complete profile shortcut selection or an incomplete
/// custom configuration that still requires one or more shortcuts.
///
/// The associated optional value is intentional:
///
/// - `.complete(nil)` means Use Default.
/// - `.complete(.some(.disabled))` means Off.
/// - `.incomplete` means that the selected custom mode is missing input.
nonisolated enum ProfileShortcutConfigurationOverrideProposal:
    Equatable
{
    case incomplete

    case complete(
        RemappingShortcutConfiguration?
    )

    /// Resolves the configuration that would be effective for the profile.
    ///
    /// Incomplete editor input cannot produce an effective configuration.
    func effectiveConfiguration(
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) -> RemappingShortcutConfiguration? {
        switch self {
        case .incomplete:
            return nil

        case .complete(
            let shortcutConfigurationOverride
        ):
            return shortcutConfigurationOverride
                ?? defaultConfiguration
        }
    }
}

/// Owns the temporary presentation state used by the profile shortcut sheet.
///
/// This value is not persisted directly. Once the selection is complete, the
/// resulting override is passed to `HomeConfigurationEditorSession`, which
/// records the selected mode and updates persistent shortcut memory as one Home
/// Undo/Redo action.
nonisolated struct ProfileShortcutConfigurationDraft:
    Equatable
{
    /// Suggested shortcut used when no remembered Toggle value exists.
    static let defaultToggleShortcut =
        AppPreferences
            .defaultToggleShortcut

    /// Suggested Enable shortcut used when no remembered value exists.
    static let defaultEnableShortcut =
        KeyCombination(
            keyCode:
                KeyCode.e,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )

    /// Suggested Disable shortcut used when no remembered value exists.
    static let defaultDisableShortcut =
        KeyCombination(
            keyCode:
                KeyCode.d,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )

    var mode:
        ProfileShortcutConfigurationMode

    var toggleShortcut:
        KeyCombination?

    var enableShortcut:
        KeyCombination?

    var disableShortcut:
        KeyCombination?

    /// Creates an editor draft from the active override and the profile's
    /// persistent custom-shortcut memory.
    ///
    /// Remembered values seed hidden custom modes even while the profile uses
    /// Default or Off. A currently active Toggle or Separate override remains
    /// authoritative if it differs from the remembered value.
    init(
        shortcutConfigurationOverride:
            RemappingShortcutConfiguration?,
        shortcutMemory:
            RemappingProfileShortcutMemory = .empty
    ) {
        toggleShortcut =
            shortcutMemory.toggleShortcut
            ?? Self.defaultToggleShortcut

        enableShortcut =
            shortcutMemory.enableShortcut
            ?? Self.defaultEnableShortcut

        disableShortcut =
            shortcutMemory.disableShortcut
            ?? Self.defaultDisableShortcut

        guard
            let shortcutConfigurationOverride
        else {
            mode =
                .useDefault

            return
        }

        switch shortcutConfigurationOverride {
        case .disabled:
            mode =
                .off

        case .toggle(
            let shortcut
        ):
            mode =
                .toggle

            toggleShortcut =
                shortcut

        case .separate(
            let enable,
            let disable
        ):
            mode =
                .separate

            enableShortcut =
                enable

            disableShortcut =
                disable
        }
    }

    /// Returns the complete override represented by the current controls.
    ///
    /// The sheet uses `.incomplete` to disable Apply while a required shortcut
    /// is missing.
    var proposal:
        ProfileShortcutConfigurationOverrideProposal
    {
        switch mode {
        case .useDefault:
            return .complete(
                nil
            )

        case .off:
            return .complete(
                .disabled
            )

        case .toggle:
            guard
                let toggleShortcut
            else {
                return .incomplete
            }

            return .complete(
                .toggle(
                    toggleShortcut
                )
            )

        case .separate:
            guard
                let enableShortcut,
                let disableShortcut
            else {
                return .incomplete
            }

            return .complete(
                .separate(
                    enable:
                        enableShortcut,
                    disable:
                        disableShortcut
                )
            )
        }
    }

    /// Indicates whether the complete editor value differs from the override
    /// that was present when the sheet opened.
    func differs(
        from originalOverride:
            RemappingShortcutConfiguration?
    ) -> Bool {
        switch proposal {
        case .incomplete:
            return true

        case .complete(
            let proposedOverride
        ):
            return proposedOverride
                != originalOverride
        }
    }
}

/// Produces stable user-facing text for the Profiles table and shortcut sheet.
///
/// Keeping these strings outside AppKit controls makes their behavior testable
/// without creating windows.
nonisolated enum ProfileShortcutConfigurationPresentation {

    /// Compact value displayed in the Profiles table's Shortcut column.
    static func tableTitle(
        for shortcutConfigurationOverride:
            RemappingShortcutConfiguration?
    ) -> String {
        guard
            let shortcutConfigurationOverride
        else {
            return "Default"
        }

        switch shortcutConfigurationOverride {
        case .disabled:
            return "Off"

        case .toggle(
            let shortcut
        ):
            return KeyCombinationDisplayName
                .name(
                    for:
                        shortcut
                )

        case .separate:
            return "Separate"
        }
    }

    /// Detailed value suitable for tooltips and sheet descriptions.
    static func detailTitle(
        for shortcutConfigurationOverride:
            RemappingShortcutConfiguration?,
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) -> String {
        guard
            let shortcutConfigurationOverride
        else {
            return "Uses Default Global Shortcuts: "
                + configurationTitle(
                    defaultConfiguration
                )
        }

        return configurationTitle(
            shortcutConfigurationOverride
        )
    }

    /// Human-readable title for one complete shortcut configuration.
    static func configurationTitle(
        _ configuration:
            RemappingShortcutConfiguration
    ) -> String {
        switch configuration {
        case .disabled:
            return "Off"

        case .toggle(
            let shortcut
        ):
            return "Toggle: "
                + KeyCombinationDisplayName
                    .name(
                        for:
                            shortcut
                    )

        case .separate(
            let enable,
            let disable
        ):
            return "Enable: "
                + KeyCombinationDisplayName
                    .name(
                        for:
                            enable
                    )
                + " · Disable: "
                + KeyCombinationDisplayName
                    .name(
                        for:
                            disable
                    )
        }
    }

    static func modeTitle(
        _ mode:
            ProfileShortcutConfigurationMode
    ) -> String {
        switch mode {
        case .useDefault:
            return "Use Default"

        case .off:
            return "Off"

        case .toggle:
            return "Toggle"

        case .separate:
            return "Separate"
        }
    }
}
