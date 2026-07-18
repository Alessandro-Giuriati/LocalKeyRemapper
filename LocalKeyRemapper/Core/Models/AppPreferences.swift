//
//  AppPreferences.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Foundation

/// Defines how remapping should behave when the application launches.
nonisolated enum RemappingLaunchBehavior:
    String,
    Codable,
    CaseIterable
{
    /// The application always starts with remapping disabled.
    case alwaysOff

    /// The application restores the last enabled or disabled state.
    case restoreLastState

    /// The application always attempts to enable remapping.
    case alwaysOn
}

/// Contains application preferences that are safe to persist locally.
///
/// These preferences describe application behavior and configured
/// shortcuts only. They never contain keyboard input or key-press history.
nonisolated struct AppPreferences:
    Codable,
    Equatable
{
    /// The global shortcut used for new installations and for migration
    /// from preference formats that did not contain a shortcut setting.
    static let defaultToggleShortcut =
        KeyCombination(
            keyCode: KeyCode.r,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )

    /// Defines how remapping should behave at application launch.
    var launchBehavior:
        RemappingLaunchBehavior

    /// Stores whether remapping was enabled after the most recent
    /// user-visible state change.
    var lastRemappingEnabled:
        Bool

    /// Stores the configured global shortcut used to toggle remapping.
    ///
    /// A nil value explicitly means that the global shortcut is disabled.
    var toggleShortcut:
        KeyCombination?

    /// Safe preferences used when nothing has been stored yet.
    static let standard =
        AppPreferences(
            launchBehavior:
                .alwaysOff,
            lastRemappingEnabled:
                false,
            toggleShortcut:
                defaultToggleShortcut
        )

    /// Indicates whether remapping should be enabled for the
    /// currently stored launch behavior.
    var shouldEnableRemappingAtLaunch:
        Bool
    {
        switch launchBehavior {
        case .alwaysOff:
            return false

        case .restoreLastState:
            return lastRemappingEnabled

        case .alwaysOn:
            return true
        }
    }

    init(
        launchBehavior:
            RemappingLaunchBehavior,
        lastRemappingEnabled:
            Bool,
        toggleShortcut:
            KeyCombination? =
                AppPreferences
                    .defaultToggleShortcut
    ) {
        self.launchBehavior =
            launchBehavior

        self.lastRemappingEnabled =
            lastRemappingEnabled

        self.toggleShortcut =
            toggleShortcut
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case launchBehavior
        case lastRemappingEnabled
        case toggleShortcut

        /// Legacy key used by the previous two-state preference.
        case enableRemappingAtLaunch
    }

    init(from decoder: Decoder)
        throws
    {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        if let launchBehavior =
            try container.decodeIfPresent(
                RemappingLaunchBehavior.self,
                forKey:
                    .launchBehavior
            )
        {
            self.launchBehavior =
                launchBehavior
        } else {
            let legacyEnableAtLaunch =
                try container.decodeIfPresent(
                    Bool.self,
                    forKey:
                        .enableRemappingAtLaunch
                ) ?? false

            launchBehavior =
                legacyEnableAtLaunch
                    ? .alwaysOn
                    : .alwaysOff
        }

        lastRemappingEnabled =
            try container.decodeIfPresent(
                Bool.self,
                forKey:
                    .lastRemappingEnabled
            ) ?? false

        if container.contains(
            .toggleShortcut
        ) {
            toggleShortcut =
                try container.decodeIfPresent(
                    KeyCombination.self,
                    forKey:
                        .toggleShortcut
                )
        } else {
            /// The stored data predates global shortcut support.
            toggleShortcut =
                AppPreferences
                    .defaultToggleShortcut
        }
    }

    func encode(to encoder: Encoder)
        throws
    {
        var container =
            encoder.container(
                keyedBy:
                    CodingKeys.self
            )

        try container.encode(
            launchBehavior,
            forKey:
                .launchBehavior
        )

        try container.encode(
            lastRemappingEnabled,
            forKey:
                .lastRemappingEnabled
        )

        if let toggleShortcut {
            try container.encode(
                toggleShortcut,
                forKey:
                    .toggleShortcut
            )
        } else {
            /// Encoding null distinguishes an intentionally disabled
            /// shortcut from an older preference format where the
            /// property did not exist at all.
            try container.encodeNil(
                forKey:
                    .toggleShortcut
            )
        }
    }
}
