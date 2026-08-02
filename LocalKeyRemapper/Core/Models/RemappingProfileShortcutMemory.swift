//
//  RemappingProfileShortcutMemory.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation

/// Stores the most recently configured custom shortcuts for one profile.
///
/// This memory is separate from the profile's currently selected shortcut
/// mode:
///
/// - Use Default and Off do not erase remembered custom shortcuts.
/// - Toggle updates only `toggleShortcut`.
/// - Separate updates only `enableShortcut` and `disableShortcut`.
///
/// The remembered values are configuration data only. They do not contain
/// keyboard history, captured input logs, analytics, or telemetry.
nonisolated struct RemappingProfileShortcutMemory:
    Codable,
    Equatable
{
    /// Most recently configured profile-specific Toggle shortcut.
    var toggleShortcut:
        KeyCombination?

    /// Most recently configured profile-specific Enable shortcut.
    var enableShortcut:
        KeyCombination?

    /// Most recently configured profile-specific Disable shortcut.
    var disableShortcut:
        KeyCombination?

    static let empty =
        RemappingProfileShortcutMemory()

    init(
        toggleShortcut:
            KeyCombination? = nil,
        enableShortcut:
            KeyCombination? = nil,
        disableShortcut:
            KeyCombination? = nil
    ) {
        self.toggleShortcut =
            toggleShortcut

        self.enableShortcut =
            enableShortcut

        self.disableShortcut =
            disableShortcut
    }

    /// Creates memory from an existing shortcut override.
    ///
    /// This initializer is used when profiles persisted before shortcut memory
    /// was introduced are decoded:
    ///
    /// - an existing Toggle override seeds the remembered Toggle shortcut;
    /// - an existing Separate override seeds Enable and Disable;
    /// - Use Default and Off start with empty memory.
    init(
        shortcutConfiguration:
            RemappingShortcutConfiguration?
    ) {
        toggleShortcut =
            nil

        enableShortcut =
            nil

        disableShortcut =
            nil

        remember(
            shortcutConfiguration
        )
    }

    /// Returns a copy updated with the supplied configuration.
    ///
    /// Use Default and Off intentionally preserve every remembered value.
    func remembering(
        _ shortcutConfiguration:
            RemappingShortcutConfiguration?
    ) -> RemappingProfileShortcutMemory {
        var updatedMemory =
            self

        updatedMemory.remember(
            shortcutConfiguration
        )

        return updatedMemory
    }

    /// Updates only the remembered values represented by the supplied mode.
    ///
    /// Switching away from a custom mode never clears the previous values.
    mutating func remember(
        _ shortcutConfiguration:
            RemappingShortcutConfiguration?
    ) {
        guard
            let shortcutConfiguration
        else {
            return
        }

        switch shortcutConfiguration {
        case .disabled:
            return

        case .toggle(
            let shortcut
        ):
            toggleShortcut =
                shortcut

        case .separate(
            let enable,
            let disable
        ):
            enableShortcut =
                enable

            disableShortcut =
                disable
        }
    }
}
