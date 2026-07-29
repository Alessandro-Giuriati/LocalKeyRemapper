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
/// Profile identity is based exclusively on `id`. The editable profile name
/// is never used as persistent identity.
nonisolated struct RemappingProfile:
    Codable,
    Equatable,
    Identifiable
{
    /// Stable identity preserved across renaming, saving, and Undo/Redo.
    let id: UUID

    /// User-editable display name.
    var name: String

    /// Date on which the profile was originally created.
    let createdAt: Date

    /// Date of the most recent persistent profile modification.
    var updatedAt: Date

    /// Complete remapping configuration owned by this profile.
    var rules: [RemapRule]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = Date(),
        updatedAt: Date? = nil,
        rules: [RemapRule] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.rules = rules
    }
}
