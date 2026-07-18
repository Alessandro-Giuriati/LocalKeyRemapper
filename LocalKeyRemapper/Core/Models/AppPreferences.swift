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
            keyCode:
                KeyCode.r,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )

    /// The complete default shortcut configuration.
    static let defaultShortcutConfiguration =
        RemappingShortcutConfiguration
            .toggle(
                defaultToggleShortcut
            )

    /// Defines how remapping should behave at application launch.
    var launchBehavior:
        RemappingLaunchBehavior

    /// Stores whether remapping was enabled after the most recent
    /// user-visible state change.
    var lastRemappingEnabled:
        Bool

    /// Stores the complete global shortcut configuration.
    var shortcutConfiguration:
        RemappingShortcutConfiguration

    /// Temporary compatibility property used by the existing
    /// single-shortcut controller.
    ///
    /// This property can be removed after the controller and interface
    /// have been migrated to RemappingShortcutConfiguration.
    var toggleShortcut:
        KeyCombination?
    {
        get {
            guard
                case .toggle(let shortcut) =
                    shortcutConfiguration
            else {
                return nil
            }

            return shortcut
        }

        set {
            if let newValue {
                shortcutConfiguration =
                    .toggle(
                        newValue
                    )
            } else {
                shortcutConfiguration =
                    .disabled
            }
        }
    }

    /// Safe preferences used when nothing has been stored yet.
    static let standard =
        AppPreferences(
            launchBehavior:
                .alwaysOff,
            lastRemappingEnabled:
                false,
            shortcutConfiguration:
                defaultShortcutConfiguration
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
        shortcutConfiguration:
            RemappingShortcutConfiguration =
                AppPreferences
                    .defaultShortcutConfiguration
    ) {
        self.launchBehavior =
            launchBehavior

        self.lastRemappingEnabled =
            lastRemappingEnabled

        self.shortcutConfiguration =
            shortcutConfiguration
    }

    /// Compatibility initializer for code and tests that still use
    /// the previous optional toggle-shortcut representation.
    init(
        launchBehavior:
            RemappingLaunchBehavior,
        lastRemappingEnabled:
            Bool,
        toggleShortcut:
            KeyCombination?
    ) {
        let shortcutConfiguration:
            RemappingShortcutConfiguration

        if let toggleShortcut {
            shortcutConfiguration =
                .toggle(
                    toggleShortcut
                )
        } else {
            shortcutConfiguration =
                .disabled
        }

        self.init(
            launchBehavior:
                launchBehavior,
            lastRemappingEnabled:
                lastRemappingEnabled,
            shortcutConfiguration:
                shortcutConfiguration
        )
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case launchBehavior
        case lastRemappingEnabled
        case shortcutConfiguration

        /// Legacy shortcut key used before multiple shortcut modes.
        case toggleShortcut

        /// Legacy key used by the previous two-state launch preference.
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
            .shortcutConfiguration
        ) {
            shortcutConfiguration =
                try container.decode(
                    RemappingShortcutConfiguration.self,
                    forKey:
                        .shortcutConfiguration
                )
        } else if container.contains(
            .toggleShortcut
        ) {
            let legacyToggleShortcut =
                try container.decodeIfPresent(
                    KeyCombination.self,
                    forKey:
                        .toggleShortcut
                )

            if let legacyToggleShortcut {
                shortcutConfiguration =
                    .toggle(
                        legacyToggleShortcut
                    )
            } else {
                shortcutConfiguration =
                    .disabled
            }
        } else {
            /// The stored data predates global shortcut support.
            shortcutConfiguration =
                AppPreferences
                    .defaultShortcutConfiguration
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

        try container.encode(
            shortcutConfiguration,
            forKey:
                .shortcutConfiguration
        )
    }
}
