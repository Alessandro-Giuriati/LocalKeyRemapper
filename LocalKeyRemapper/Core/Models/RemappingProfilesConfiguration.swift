//
//  RemappingProfilesConfiguration.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Contains every configured remapping profile and identifies the one selected
/// for runtime remapping.
///
/// This model stores explicit configuration only. It does not contain
/// presentation state such as searching, sorting, selection, or scrolling.
nonisolated struct RemappingProfilesConfiguration:
    Codable,
    Equatable
{
    /// Profiles in their persistent collection order.
    var profiles: [RemappingProfile]

    /// Stable identity of the single profile selected for runtime use.
    var activeProfileID: UUID

    init(
        profiles: [RemappingProfile],
        activeProfileID: UUID
    ) {
        self.profiles = profiles
        self.activeProfileID = activeProfileID
    }

    /// Returns the currently selected profile when the configuration is valid.
    var activeProfile: RemappingProfile? {
        profile(
            id: activeProfileID
        )
    }

    /// Resolves a profile using its stable identity rather than its name
    /// or its current visible position.
    func profile(
        id: UUID
    ) -> RemappingProfile? {
        profiles.first {
            $0.id == id
        }
    }

    /// Creates the configuration used for a new installation.
    ///
    /// Parameters are injectable so persistence tests can use deterministic
    /// identities, dates, and rules.
    static func initial(
        profileID: UUID = UUID(),
        timestamp: Date = Date(),
        defaultRules: [RemapRule] = [
            RemapRule(
                sourceKeyCode: KeyCode.v,
                destinationKeyCode: KeyCode.w
            )
        ]
    ) -> RemappingProfilesConfiguration {
        let initialProfile =
            RemappingProfile(
                id: profileID,
                name: "Profile 1",
                createdAt: timestamp,
                updatedAt: timestamp,
                rules: defaultRules
            )

        return RemappingProfilesConfiguration(
            profiles: [
                initialProfile
            ],
            activeProfileID: profileID
        )
    }
}
