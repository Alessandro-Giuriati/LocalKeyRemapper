//
//  RemappingProfile.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Represents one independent keyboard-remapping profile.
///
/// A profile owns its complete rule collection, including rule activation,
/// matching behavior, modifiers, exceptions, and bidirectional state.
///
/// A profile may also define its own global shortcut configuration. A `nil`
/// override means that the profile uses the application's default shortcut
/// configuration.
///
/// Custom shortcut memory remains separate from the currently selected mode.
/// This allows a profile to remember its previous Toggle and Separate values
/// while it temporarily uses Default or Off.
///
/// Profile identity is based exclusively on `id`. The editable profile name
/// is never used as persistent identity.
nonisolated struct RemappingProfile:
    Codable,
    Equatable,
    Identifiable
{
    /// Stable identity preserved across renaming, saving, and Undo/Redo.
    let id:
        UUID

    /// User-editable display name.
    var name:
        String

    /// Date on which the profile was originally created.
    let createdAt:
        Date

    /// Date of the most recent persistent profile modification.
    var updatedAt:
        Date

    /// Complete remapping configuration owned by this profile.
    var rules:
        [RemapRule]

    /// Optional profile-specific global shortcut configuration.
    ///
    /// - `nil` means Use Default.
    /// - `.disabled` means Off explicitly.
    /// - `.toggle` defines one profile-specific Toggle shortcut.
    /// - `.separate` defines profile-specific Enable and Disable shortcuts.
    ///
    /// An explicit override remains an override even when its value is equal
    /// to the application's current default shortcut configuration.
    var shortcutConfigurationOverride:
        RemappingShortcutConfiguration?

    /// Most recently configured custom shortcut values for this profile.
    ///
    /// These values remain available even when the current override is Use
    /// Default or Off.
    var shortcutMemory:
        RemappingProfileShortcutMemory

    init(
        id:
            UUID = UUID(),
        name:
            String,
        createdAt:
            Date = Date(),
        updatedAt:
            Date? = nil,
        rules:
            [RemapRule] = [],
        shortcutConfigurationOverride:
            RemappingShortcutConfiguration? = nil,
        shortcutMemory:
            RemappingProfileShortcutMemory? = nil
    ) {
        self.id =
            id

        self.name =
            name

        self.createdAt =
            createdAt

        self.updatedAt =
            updatedAt
                ?? createdAt

        self.rules =
            rules

        self.shortcutConfigurationOverride =
            shortcutConfigurationOverride

        self.shortcutMemory =
            shortcutMemory
                ?? RemappingProfileShortcutMemory(
                    shortcutConfiguration:
                        shortcutConfigurationOverride
                )
    }

    private enum CodingKeys:
        String,
        CodingKey
    {
        case id
        case name
        case createdAt
        case updatedAt
        case rules
        case shortcutConfigurationOverride
        case shortcutMemory
    }

    /// Decodes both current profiles and profiles persisted before
    /// profile-specific shortcut memory was introduced.
    ///
    /// Older payloads may omit:
    ///
    /// - `shortcutConfigurationOverride`, which migrates to Use Default;
    /// - `shortcutMemory`, which is reconstructed from the existing override.
    init(
        from decoder:
            Decoder
    ) throws {
        let container =
            try decoder.container(
                keyedBy:
                    CodingKeys.self
            )

        id =
            try container.decode(
                UUID.self,
                forKey:
                    .id
            )

        name =
            try container.decode(
                String.self,
                forKey:
                    .name
            )

        createdAt =
            try container.decode(
                Date.self,
                forKey:
                    .createdAt
            )

        updatedAt =
            try container.decode(
                Date.self,
                forKey:
                    .updatedAt
            )

        rules =
            try container.decode(
                [RemapRule].self,
                forKey:
                    .rules
            )

        shortcutConfigurationOverride =
            try container.decodeIfPresent(
                RemappingShortcutConfiguration.self,
                forKey:
                    .shortcutConfigurationOverride
            )

        shortcutMemory =
            try container.decodeIfPresent(
                RemappingProfileShortcutMemory.self,
                forKey:
                    .shortcutMemory
            )
            ?? RemappingProfileShortcutMemory(
                shortcutConfiguration:
                    shortcutConfigurationOverride
            )
    }

    func encode(
        to encoder:
            Encoder
    ) throws {
        var container =
            encoder.container(
                keyedBy:
                    CodingKeys.self
            )

        try container.encode(
            id,
            forKey:
                .id
        )

        try container.encode(
            name,
            forKey:
                .name
        )

        try container.encode(
            createdAt,
            forKey:
                .createdAt
        )

        try container.encode(
            updatedAt,
            forKey:
                .updatedAt
        )

        try container.encode(
            rules,
            forKey:
                .rules
        )

        try container.encodeIfPresent(
            shortcutConfigurationOverride,
            forKey:
                .shortcutConfigurationOverride
        )

        try container.encode(
            shortcutMemory,
            forKey:
                .shortcutMemory
        )
    }
}
