//
//  RemappingProfilesConfigurationValidator.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Represents a validation problem affecting one profile name.
nonisolated enum RemappingProfileNameValidationError:
    Error,
    Equatable
{
    /// The name contains a control character or line break.
    case containsForbiddenCharacter

    /// The name is empty after surrounding whitespace is removed.
    case empty
}

/// Represents a validation problem affecting the complete profile collection.
nonisolated enum RemappingProfilesConfigurationValidationError:
    Error,
    Equatable
{
    /// A valid configuration must always contain at least one profile.
    case noProfiles

    /// Two or more profiles use the same stable identity.
    case duplicateProfileID(UUID)

    /// The selected active profile does not exist in the collection.
    case missingActiveProfile(UUID)

    /// One profile contains an invalid name.
    case invalidProfileName(
        profileID: UUID,
        reason: RemappingProfileNameValidationError
    )

    /// Two profiles use the same normalized, case-sensitive name.
    case duplicateProfileName(String)
}

/// Defines the operations required to normalize and validate profile data.
nonisolated protocol RemappingProfilesConfigurationValidating {

    /// Removes allowed surrounding whitespace and rejects unsafe names.
    func normalizedProfileName(
        _ name: String
    ) throws -> String

    /// Returns a normalized and fully validated configuration.
    func normalizedConfiguration(
        _ configuration: RemappingProfilesConfiguration
    ) throws -> RemappingProfilesConfiguration

    /// Validates a configuration without returning its normalized copy.
    func validate(
        _ configuration: RemappingProfilesConfiguration
    ) throws
}

/// Validates profile data without accessing storage, the UI,
/// or the keyboard-remapping runtime.
nonisolated struct RemappingProfilesConfigurationValidator:
    RemappingProfilesConfigurationValidating
{
    func normalizedProfileName(
        _ name: String
    ) throws -> String {
        let containsControlCharacter =
            name.rangeOfCharacter(
                from: .controlCharacters
            ) != nil

        let containsLineBreak =
            name.rangeOfCharacter(
                from: .newlines
            ) != nil

        guard
            !containsControlCharacter,
            !containsLineBreak
        else {
            throw RemappingProfileNameValidationError
                .containsForbiddenCharacter
        }

        let normalizedName =
            name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )

        guard
            !normalizedName.isEmpty
        else {
            throw RemappingProfileNameValidationError
                .empty
        }

        return normalizedName
    }

    func normalizedConfiguration(
        _ configuration: RemappingProfilesConfiguration
    ) throws -> RemappingProfilesConfiguration {
        guard
            !configuration.profiles.isEmpty
        else {
            throw RemappingProfilesConfigurationValidationError
                .noProfiles
        }

        try validateProfileIDs(
            configuration.profiles
        )

        guard
            configuration.profiles.contains(
                where: {
                    $0.id == configuration.activeProfileID
                }
            )
        else {
            throw RemappingProfilesConfigurationValidationError
                .missingActiveProfile(
                    configuration.activeProfileID
                )
        }

        var normalizedProfiles:
            [RemappingProfile] = []

        normalizedProfiles.reserveCapacity(
            configuration.profiles.count
        )

        var registeredNames =
            Set<String>()

        for profile in configuration.profiles {
            let normalizedName: String

            do {
                normalizedName =
                    try normalizedProfileName(
                        profile.name
                    )
            } catch let error
                as RemappingProfileNameValidationError
            {
                throw RemappingProfilesConfigurationValidationError
                    .invalidProfileName(
                        profileID:
                            profile.id,
                        reason:
                            error
                    )
            }

            guard
                registeredNames.insert(
                    normalizedName
                ).inserted
            else {
                throw RemappingProfilesConfigurationValidationError
                    .duplicateProfileName(
                        normalizedName
                    )
            }

            var normalizedProfile =
                profile

            normalizedProfile.name =
                normalizedName

            normalizedProfiles.append(
                normalizedProfile
            )
        }

        return RemappingProfilesConfiguration(
            profiles:
                normalizedProfiles,
            activeProfileID:
                configuration.activeProfileID
        )
    }

    func validate(
        _ configuration: RemappingProfilesConfiguration
    ) throws {
        _ =
            try normalizedConfiguration(
                configuration
            )
    }

    private func validateProfileIDs(
        _ profiles: [RemappingProfile]
    ) throws {
        var registeredIDs =
            Set<UUID>()

        for profile in profiles {
            guard
                registeredIDs.insert(
                    profile.id
                ).inserted
            else {
                throw RemappingProfilesConfigurationValidationError
                    .duplicateProfileID(
                        profile.id
                    )
            }
        }
    }
}
