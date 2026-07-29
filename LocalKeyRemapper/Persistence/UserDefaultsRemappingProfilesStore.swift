//
//  UserDefaultsRemappingProfilesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation

/// Represents a failure while verifying a profiles configuration
/// immediately after writing it to UserDefaults.
nonisolated enum UserDefaultsRemappingProfilesStoreError:
    Error,
    Equatable
{
    case persistenceVerificationFailed
}

/// Persists the complete remapping-profiles configuration in the
/// application's local UserDefaults domain.
///
/// The store performs a one-time migration from the previous rules-only
/// payload when no profiles payload exists yet.
///
/// It stores configured remapping data only. It never receives, records,
/// or stores keyboard input.
@MainActor
final class UserDefaultsRemappingProfilesStore:
    RemappingProfilesStore
{
    private enum StorageKey {
        static let configuration =
            "remappingProfiles.v1"

        static let legacyRules =
            "remappingRules.v1"
    }

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let validator:
        RemappingProfilesConfigurationValidating

    private let defaultRules: [RemapRule]
    private let profileIDProvider: () -> UUID
    private let dateProvider: () -> Date

    init(
        userDefaults: UserDefaults = .standard,
        validator:
            RemappingProfilesConfigurationValidating =
                RemappingProfilesConfigurationValidator(),
        defaultRules: [RemapRule] = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ],
        profileIDProvider: @escaping () -> UUID = {
            UUID()
        },
        dateProvider: @escaping () -> Date = {
            Date()
        }
    ) {
        self.userDefaults =
            userDefaults

        self.validator =
            validator

        self.defaultRules =
            defaultRules

        self.profileIDProvider =
            profileIDProvider

        self.dateProvider =
            dateProvider

        encoder =
            JSONEncoder()

        decoder =
            JSONDecoder()
    }

    func loadConfiguration() throws
        -> RemappingProfilesConfiguration
    {
        if let persistedData =
            userDefaults.data(
                forKey:
                    StorageKey.configuration
            )
        {
            return try loadPersistedConfiguration(
                from:
                    persistedData
            )
        }

        if let legacyData =
            userDefaults.data(
                forKey:
                    StorageKey.legacyRules
            )
        {
            return try migrateLegacyRules(
                from:
                    legacyData
            )
        }

        let initialConfiguration =
            RemappingProfilesConfiguration.initial(
                profileID:
                    profileIDProvider(),
                timestamp:
                    dateProvider(),
                defaultRules:
                    defaultRules
            )

        try saveConfiguration(
            initialConfiguration
        )

        return try validator.normalizedConfiguration(
            initialConfiguration
        )
    }

    func saveConfiguration(
        _ configuration: RemappingProfilesConfiguration
    ) throws {
        let normalizedConfiguration =
            try validator.normalizedConfiguration(
                configuration
            )

        let encodedData =
            try encoder.encode(
                normalizedConfiguration
            )

        let previousData =
            userDefaults.data(
                forKey:
                    StorageKey.configuration
            )

        userDefaults.set(
            encodedData,
            forKey:
                StorageKey.configuration
        )

        guard
            let persistedData =
                userDefaults.data(
                    forKey:
                        StorageKey.configuration
                ),
            let verifiedConfiguration =
                try? decoder.decode(
                    RemappingProfilesConfiguration.self,
                    from:
                        persistedData
                ),
            verifiedConfiguration
                == normalizedConfiguration
        else {
            restorePreviousConfigurationData(
                previousData
            )

            throw UserDefaultsRemappingProfilesStoreError
                .persistenceVerificationFailed
        }
    }

    private func loadPersistedConfiguration(
        from data: Data
    ) throws -> RemappingProfilesConfiguration {
        let decodedConfiguration =
            try decoder.decode(
                RemappingProfilesConfiguration.self,
                from:
                    data
            )

        return try validator.normalizedConfiguration(
            decodedConfiguration
        )
    }

    private func migrateLegacyRules(
        from data: Data
    ) throws -> RemappingProfilesConfiguration {
        // Decode before writing anything. If the legacy payload is corrupt,
        // migration fails without creating a partial profiles payload.
        let legacyRules =
            try decoder.decode(
                [RemapRule].self,
                from:
                    data
            )

        let migratedConfiguration =
            RemappingProfilesConfiguration.initial(
                profileID:
                    profileIDProvider(),
                timestamp:
                    dateProvider(),
                defaultRules:
                    legacyRules
            )

        try saveConfiguration(
            migratedConfiguration
        )

        // The legacy key is intentionally preserved. This keeps the previous
        // payload available during the staged introduction of profiles.
        return try validator.normalizedConfiguration(
            migratedConfiguration
        )
    }

    private func restorePreviousConfigurationData(
        _ previousData: Data?
    ) {
        if let previousData {
            userDefaults.set(
                previousData,
                forKey:
                    StorageKey.configuration
            )
        } else {
            userDefaults.removeObject(
                forKey:
                    StorageKey.configuration
            )
        }
    }
}
