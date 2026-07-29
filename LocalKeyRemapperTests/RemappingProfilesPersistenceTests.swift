//
//  RemappingProfilesPersistenceTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class RemappingProfilesPersistenceTests:
    XCTestCase
{
    private enum StorageKey {
        static let configuration =
            "remappingProfiles.v1"

        static let legacyRules =
            "remappingRules.v1"
    }

    func testNewInstallationCreatesAndPersistsInitialConfiguration()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let profileID =
            UUID(
                uuidString:
                    "8CCF909B-D73E-4F7E-A94D-6E9797E3FF72"
            )!

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let defaultRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        let store =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults,
                defaultRules:
                    defaultRules,
                profileIDProvider: {
                    profileID
                },
                dateProvider: {
                    timestamp
                }
            )

        let loadedConfiguration =
            try store.loadConfiguration()

        let expectedConfiguration =
            RemappingProfilesConfiguration.initial(
                profileID:
                    profileID,
                timestamp:
                    timestamp,
                defaultRules:
                    defaultRules
            )

        XCTAssertEqual(
            loadedConfiguration,
            expectedConfiguration
        )

        let persistedData =
            try XCTUnwrap(
                context.userDefaults.data(
                    forKey:
                        StorageKey.configuration
                )
            )

        let persistedConfiguration =
            try JSONDecoder().decode(
                RemappingProfilesConfiguration.self,
                from:
                    persistedData
            )

        XCTAssertEqual(
            persistedConfiguration,
            expectedConfiguration
        )

        XCTAssertNil(
            context.userDefaults.data(
                forKey:
                    StorageKey.legacyRules
            )
        )
    }

    func testSavingAndLoadingPreservesCompleteProfilesConfiguration()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let firstProfileID =
            UUID(
                uuidString:
                    "6444536C-CB24-491E-B062-F2A3A09658B2"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "EB298B6D-E922-46CC-8535-1465987E436A"
            )!

        let firstProfile =
            RemappingProfile(
                id:
                    firstProfileID,
                name:
                    "  Gaming  ",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp.addingTimeInterval(
                        100
                    ),
                rules: [
                    makeAdvancedRule()
                ]
            )

        let secondProfile =
            RemappingProfile(
                id:
                    secondProfileID,
                name:
                    "Work",
                createdAt:
                    timestamp.addingTimeInterval(
                        200
                    ),
                updatedAt:
                    timestamp.addingTimeInterval(
                        300
                    ),
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.b,
                        destinationKeyCode:
                            KeyCode.j,
                        isEnabled:
                            true,
                        isBidirectional:
                            false
                    )
                ]
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    firstProfile,
                    secondProfile
                ],
                activeProfileID:
                    secondProfileID
            )

        let store =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults
            )

        try store.saveConfiguration(
            configuration
        )

        let loadedConfiguration =
            try store.loadConfiguration()

        var expectedConfiguration =
            configuration

        expectedConfiguration.profiles[0].name =
            "Gaming"

        XCTAssertEqual(
            loadedConfiguration,
            expectedConfiguration
        )

        XCTAssertEqual(
            loadedConfiguration.activeProfileID,
            secondProfileID
        )

        XCTAssertEqual(
            loadedConfiguration.profiles[0].rules,
            [
                makeAdvancedRule()
            ]
        )
    }

    func testPersistedProfileIdentityRemainsStableAcrossStoreInstances()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let originalProfileID =
            UUID(
                uuidString:
                    "5D506C5C-C046-4F04-8593-F73EA52D02BA"
            )!

        let unusedReplacementID =
            UUID(
                uuidString:
                    "95B23C48-48E7-448B-969C-E5BA590B639F"
            )!

        let firstTimestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let unusedReplacementTimestamp =
            Date(
                timeIntervalSince1970:
                    1_800_000_000
            )

        let firstStore =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults,
                profileIDProvider: {
                    originalProfileID
                },
                dateProvider: {
                    firstTimestamp
                }
            )

        let firstConfiguration =
            try firstStore.loadConfiguration()

        let secondStore =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults,
                profileIDProvider: {
                    unusedReplacementID
                },
                dateProvider: {
                    unusedReplacementTimestamp
                }
            )

        let secondConfiguration =
            try secondStore.loadConfiguration()

        XCTAssertEqual(
            secondConfiguration,
            firstConfiguration
        )

        XCTAssertEqual(
            secondConfiguration.activeProfileID,
            originalProfileID
        )

        XCTAssertEqual(
            secondConfiguration.activeProfile?.createdAt,
            firstTimestamp
        )
    }

    func testLegacyRulesMigrationPreservesCompleteRuleData()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let legacyRules = [
            makeAdvancedRule(),
            RemapRule(
                sourceKeyCode:
                    KeyCode.n,
                destinationKeyCode:
                    KeyCode.r,
                isEnabled:
                    true,
                isBidirectional:
                    false
            )
        ]

        let legacyData =
            try JSONEncoder().encode(
                legacyRules
            )

        context.userDefaults.set(
            legacyData,
            forKey:
                StorageKey.legacyRules
        )

        let profileID =
            UUID(
                uuidString:
                    "35AA620B-8DA8-47C4-BE65-486949DD6510"
            )!

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let store =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults,
                profileIDProvider: {
                    profileID
                },
                dateProvider: {
                    timestamp
                }
            )

        let configuration =
            try store.loadConfiguration()

        XCTAssertEqual(
            configuration.activeProfileID,
            profileID
        )

        XCTAssertEqual(
            configuration.profiles.count,
            1
        )

        XCTAssertEqual(
            configuration.profiles[0].name,
            "Profile 1"
        )

        XCTAssertEqual(
            configuration.profiles[0].createdAt,
            timestamp
        )

        XCTAssertEqual(
            configuration.profiles[0].updatedAt,
            timestamp
        )

        XCTAssertEqual(
            configuration.profiles[0].rules,
            legacyRules
        )

        XCTAssertNotNil(
            context.userDefaults.data(
                forKey:
                    StorageKey.configuration
            )
        )

        XCTAssertEqual(
            context.userDefaults.data(
                forKey:
                    StorageKey.legacyRules
            ),
            legacyData
        )
    }

    func testLegacyMigrationRunsOnlyOnce()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let originalLegacyRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]

        context.userDefaults.set(
            try JSONEncoder().encode(
                originalLegacyRules
            ),
            forKey:
                StorageKey.legacyRules
        )

        let originalProfileID =
            UUID(
                uuidString:
                    "5924E099-DC34-4149-ABAE-95F77604F8E4"
            )!

        let firstStore =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults,
                profileIDProvider: {
                    originalProfileID
                }
            )

        let migratedConfiguration =
            try firstStore.loadConfiguration()

        let changedLegacyRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.b,
                destinationKeyCode:
                    KeyCode.j
            )
        ]

        context.userDefaults.set(
            try JSONEncoder().encode(
                changedLegacyRules
            ),
            forKey:
                StorageKey.legacyRules
        )

        let unusedReplacementID =
            UUID(
                uuidString:
                    "D858D1F0-D92E-4581-AE73-767C7A82F84A"
            )!

        let secondStore =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults,
                profileIDProvider: {
                    unusedReplacementID
                }
            )

        let reloadedConfiguration =
            try secondStore.loadConfiguration()

        XCTAssertEqual(
            reloadedConfiguration,
            migratedConfiguration
        )

        XCTAssertEqual(
            reloadedConfiguration.activeProfileID,
            originalProfileID
        )

        XCTAssertEqual(
            reloadedConfiguration.activeProfile?.rules,
            originalLegacyRules
        )

        XCTAssertNotEqual(
            reloadedConfiguration.activeProfile?.rules,
            changedLegacyRules
        )
    }

    func testCorruptLegacyPayloadDoesNotCreateProfilesPayload()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let corruptLegacyData =
            Data(
                "not-valid-json".utf8
            )

        context.userDefaults.set(
            corruptLegacyData,
            forKey:
                StorageKey.legacyRules
        )

        let store =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults
            )

        XCTAssertThrowsError(
            try store.loadConfiguration()
        )

        XCTAssertNil(
            context.userDefaults.data(
                forKey:
                    StorageKey.configuration
            )
        )

        XCTAssertEqual(
            context.userDefaults.data(
                forKey:
                    StorageKey.legacyRules
            ),
            corruptLegacyData
        )
    }

    func testInvalidConfigurationDoesNotOverwritePersistedData()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let validConfiguration =
            RemappingProfilesConfiguration.initial(
                profileID:
                    UUID(
                        uuidString:
                            "A60584DB-828C-4616-9C5D-845A6E6FD9AC"
                    )!,
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_700_000_000
                    )
            )

        let store =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults
            )

        try store.saveConfiguration(
            validConfiguration
        )

        let originalData =
            try XCTUnwrap(
                context.userDefaults.data(
                    forKey:
                        StorageKey.configuration
                )
            )

        let invalidConfiguration =
            RemappingProfilesConfiguration(
                profiles: [],
                activeProfileID:
                    UUID()
            )

        XCTAssertThrowsError(
            try store.saveConfiguration(
                invalidConfiguration
            )
        ) { error in
            XCTAssertEqual(
                error
                    as?
                    RemappingProfilesConfigurationValidationError,
                .noProfiles
            )
        }

        XCTAssertEqual(
            context.userDefaults.data(
                forKey:
                    StorageKey.configuration
            ),
            originalData
        )

        XCTAssertEqual(
            try store.loadConfiguration(),
            validConfiguration
        )
    }

    func testCorruptProfilesPayloadIsNotSilentlyReplacedByLegacyRules()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let corruptProfilesData =
            Data(
                "corrupt-profiles-data".utf8
            )

        let validLegacyData =
            try JSONEncoder().encode(
                [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ]
            )

        context.userDefaults.set(
            corruptProfilesData,
            forKey:
                StorageKey.configuration
        )

        context.userDefaults.set(
            validLegacyData,
            forKey:
                StorageKey.legacyRules
        )

        let store =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults
            )

        XCTAssertThrowsError(
            try store.loadConfiguration()
        )

        XCTAssertEqual(
            context.userDefaults.data(
                forKey:
                    StorageKey.configuration
            ),
            corruptProfilesData
        )

        XCTAssertEqual(
            context.userDefaults.data(
                forKey:
                    StorageKey.legacyRules
            ),
            validLegacyData
        )
    }

    private func makeAdvancedRule()
        -> RemapRule
    {
        RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        KeyCode.v
                ),
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w
                ),
            matchingMode:
                .preserveModifiers,
            overrides: [
                RemapOverride(
                    source:
                        KeyCombination(
                            keyCode:
                                KeyCode.v,
                            modifiers: [
                                .command
                            ]
                        ),
                    action:
                        .passThrough
                )
            ],
            isEnabled:
                false,
            isBidirectional:
                true
        )
    }

    private func makeContext()
        throws -> RemappingProfilesPersistenceTestContext
    {
        let suiteName =
            "RemappingProfilesPersistenceTests."
            + UUID().uuidString

        let userDefaults =
            try XCTUnwrap(
                UserDefaults(
                    suiteName:
                        suiteName
                )
            )

        return RemappingProfilesPersistenceTestContext(
            suiteName:
                suiteName,
            userDefaults:
                userDefaults
        )
    }
}

private struct RemappingProfilesPersistenceTestContext {
    let suiteName: String
    let userDefaults: UserDefaults

    func cleanUp() {
        userDefaults.removePersistentDomain(
            forName:
                suiteName
        )
    }
}
