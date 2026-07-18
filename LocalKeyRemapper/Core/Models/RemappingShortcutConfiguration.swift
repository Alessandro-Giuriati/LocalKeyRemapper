//
//  RemappingShortcutConfiguration.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import Foundation

/// Identifies the application command performed by a global shortcut.
nonisolated enum GlobalShortcutAction:
    UInt32,
    CaseIterable,
    Codable,
    Hashable
{
    /// Changes remapping from enabled to disabled or vice versa.
    case toggle = 1

    /// Enables remapping without changing it when it is already enabled.
    case enable = 2

    /// Disables remapping without changing it when it is already disabled.
    case disable = 3
}

/// Associates one global shortcut with one application command.
nonisolated struct GlobalShortcutRegistration:
    Equatable,
    Hashable
{
    let action:
        GlobalShortcutAction

    let shortcut:
        KeyCombination
}

/// Defines how keyboard shortcuts control the remapping state.
///
/// Only valid and complete states can be represented:
///
/// - no global shortcut;
/// - one shortcut that toggles remapping;
/// - two distinct shortcuts for enabling and disabling remapping.
nonisolated enum RemappingShortcutConfiguration:
    Codable,
    Equatable
{
    /// Global keyboard control is disabled.
    case disabled

    /// One shortcut toggles remapping between enabled and disabled.
    case toggle(
        KeyCombination
    )

    /// Separate shortcuts explicitly enable and disable remapping.
    case separate(
        enable:
            KeyCombination,
        disable:
            KeyCombination
    )

    /// Returns every registration required by this configuration.
    var registrations:
        [GlobalShortcutRegistration]
    {
        switch self {
        case .disabled:
            return []

        case .toggle(let shortcut):
            return [
                GlobalShortcutRegistration(
                    action:
                        .toggle,
                    shortcut:
                        shortcut
                )
            ]

        case .separate(
            let enableShortcut,
            let disableShortcut
        ):
            return [
                GlobalShortcutRegistration(
                    action:
                        .enable,
                    shortcut:
                        enableShortcut
                ),
                GlobalShortcutRegistration(
                    action:
                        .disable,
                    shortcut:
                        disableShortcut
                )
            ]
        }
    }

    /// Returns every combination that must be protected from
    /// normal remapping rules.
    var reservedCombinations:
        Set<KeyCombination>
    {
        Set(
            registrations.map {
                $0.shortcut
            }
        )
    }

    private enum Mode:
        String,
        Codable
    {
        case disabled
        case toggle
        case separate
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case mode
        case toggleShortcut
        case enableShortcut
        case disableShortcut
    }

    init(from decoder: Decoder)
        throws
    {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        let mode =
            try container.decode(
                Mode.self,
                forKey:
                    .mode
            )

        switch mode {
        case .disabled:
            self =
                .disabled

        case .toggle:
            let shortcut =
                try container.decode(
                    KeyCombination.self,
                    forKey:
                        .toggleShortcut
                )

            self =
                .toggle(
                    shortcut
                )

        case .separate:
            let enableShortcut =
                try container.decode(
                    KeyCombination.self,
                    forKey:
                        .enableShortcut
                )

            let disableShortcut =
                try container.decode(
                    KeyCombination.self,
                    forKey:
                        .disableShortcut
                )

            self =
                .separate(
                    enable:
                        enableShortcut,
                    disable:
                        disableShortcut
                )
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

        switch self {
        case .disabled:
            try container.encode(
                Mode.disabled,
                forKey:
                    .mode
            )

        case .toggle(let shortcut):
            try container.encode(
                Mode.toggle,
                forKey:
                    .mode
            )

            try container.encode(
                shortcut,
                forKey:
                    .toggleShortcut
            )

        case .separate(
            let enableShortcut,
            let disableShortcut
        ):
            try container.encode(
                Mode.separate,
                forKey:
                    .mode
            )

            try container.encode(
                enableShortcut,
                forKey:
                    .enableShortcut
            )

            try container.encode(
                disableShortcut,
                forKey:
                    .disableShortcut
            )
        }
    }
}
