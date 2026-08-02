//
//  RemappingProfileShortcutOverridePersistenceTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class RemappingProfileShortcutOverridePersistenceTests:
    XCTestCase
{
    private enum StorageKey {
        static let configuration =
            "remappingProfiles.v1"
    }

    func testProfileDefaultsToUsingDefaultShortcutConfiguration() {
        let profile =
            RemappingProfile(
                name:
                    "Gaming"
            )

        XCTAssertNil(
            profile.shortcutConfigurationOverride
        )
    }

    func testExplicitDisabledOverrideIsDistinctFromUseDefault() {
        let profileID =
            UUID(
                uuidString:
                    "C89766CE-80CB-431E-B998-AC496F6E590D"
            )!

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let useDefaultProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                shortcutConfigurationOverride:
                    nil
            )

        let disabledProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                shortcutConfigurationOverride:
                    .disabled
            )

        XCTAssertNil(
            useDefaultProfile
                .shortcutConfigurationOverride
        )

        XCTAssertEqual(
            disabledProfile
                .shortcutConfigurationOverride,
            .disabled
        )

        XCTAssertNotEqual(
            useDefaultProfile,
            disabledProfile
        )
    }

    func testCodableRoundTripPreservesEveryOverrideMode()
        throws
    {
        let overrideConfigurations:
            [RemappingShortcutConfiguration?] =
        [
            nil,
            .disabled,
            .toggle(
                KeyCombination(
                    keyCode:
                        KeyCode.n,
                    modifiers: [
                        .control,
                        .option,
                        .command
                    ]
                )
            ),
            .separate(
                enable:
                    KeyCombination(
                        keyCode:
                            KeyCode.e,
                        modifiers: [
                            .control,
                            .option
                        ]
                    ),
                disable:
                    KeyCombination(
                        keyCode:
                            KeyCode.d,
                        modifiers: [
                            .control,
                            .option
                        ]
                    )
            )
        ]

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        for (
            index,
            overrideConfiguration
        ) in overrideConfigurations.enumerated() {
            let profile =
                RemappingProfile(
                    name:
                        "Profile \(index + 1)",
                    createdAt:
                        timestamp,
                    updatedAt:
                        timestamp,
                    rules: [
                        RemapRule(
                            sourceKeyCode:
                                KeyCode.v,
                            destinationKeyCode:
                                KeyCode.w
                        )
                    ],
                    shortcutConfigurationOverride:
                        overrideConfiguration
                )

            let encodedData =
                try JSONEncoder().encode(
                    profile
                )

            let decodedProfile =
                try JSONDecoder().decode(
                    RemappingProfile.self,
                    from:
                        encodedData
                )

            XCTAssertEqual(
                decodedProfile,
                profile
            )
        }
    }

    func testDecodingLegacyProfileWithoutOverrideUsesDefault()
        throws
    {
        let profileID =
            UUID(
                uuidString:
                    "28310111-4555-47DD-937B-2CC0127EE339"
            )!

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let legacyProfile =
            LegacyRemappingProfile(
                id:
                    profileID,
                name:
                    "Legacy Profile",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ]
            )

        let legacyData =
            try JSONEncoder().encode(
                legacyProfile
            )

        let decodedProfile =
            try JSONDecoder().decode(
                RemappingProfile.self,
                from:
                    legacyData
            )

        XCTAssertEqual(
            decodedProfile.id,
            profileID
        )

        XCTAssertEqual(
            decodedProfile.name,
            "Legacy Profile"
        )

        XCTAssertEqual(
            decodedProfile.rules,
            legacyProfile.rules
        )

        XCTAssertNil(
            decodedProfile
                .shortcutConfigurationOverride
        )
    }

    func testStorePersistsProfileShortcutOverrides()
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

        let useDefaultProfile =
            RemappingProfile(
                name:
                    "Default",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                shortcutConfigurationOverride:
                    nil
            )

        let disabledProfile =
            RemappingProfile(
                name:
                    "Off",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                shortcutConfigurationOverride:
                    .disabled
            )

        let toggleProfile =
            RemappingProfile(
                name:
                    "Toggle",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                shortcutConfigurationOverride:
                    .toggle(
                        KeyCombination(
                            keyCode:
                                KeyCode.n,
                            modifiers: [
                                .control,
                                .option,
                                .command
                            ]
                        )
                    )
            )

        let separateProfile =
            RemappingProfile(
                name:
                    "Separate",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            KeyCombination(
                                keyCode:
                                    KeyCode.e,
                                modifiers: [
                                    .control,
                                    .option
                                ]
                            ),
                        disable:
                            KeyCombination(
                                keyCode:
                                    KeyCode.d,
                                modifiers: [
                                    .control,
                                    .option
                                ]
                            )
                    )
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    useDefaultProfile,
                    disabledProfile,
                    toggleProfile,
                    separateProfile
                ],
                activeProfileID:
                    separateProfile.id
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

        XCTAssertEqual(
            loadedConfiguration,
            configuration
        )
    }

    func testStoreLoadsExistingProfilesPayloadWithoutOverride()
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
                    "86375BCE-2E02-4849-A302-E40989625152"
            )!

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let legacyConfiguration =
            LegacyRemappingProfilesConfiguration(
                profiles: [
                    LegacyRemappingProfile(
                        id:
                            profileID,
                        name:
                            "Existing Profile",
                        createdAt:
                            timestamp,
                        updatedAt:
                            timestamp,
                        rules: [
                            RemapRule(
                                sourceKeyCode:
                                    KeyCode.b,
                                destinationKeyCode:
                                    KeyCode.j
                            )
                        ]
                    )
                ],
                activeProfileID:
                    profileID
            )

        let legacyData =
            try JSONEncoder().encode(
                legacyConfiguration
            )

        context.userDefaults.set(
            legacyData,
            forKey:
                StorageKey.configuration
        )

        let store =
            UserDefaultsRemappingProfilesStore(
                userDefaults:
                    context.userDefaults
            )

        let loadedConfiguration =
            try store.loadConfiguration()

        XCTAssertEqual(
            loadedConfiguration.activeProfileID,
            profileID
        )

        XCTAssertEqual(
            loadedConfiguration
                .activeProfile?
                .name,
            "Existing Profile"
        )

        XCTAssertEqual(
            loadedConfiguration
                .activeProfile?
                .rules,
            legacyConfiguration
                .profiles[0]
                .rules
        )

        XCTAssertNil(
            loadedConfiguration
                .activeProfile?
                .shortcutConfigurationOverride
        )

        try store.saveConfiguration(
            loadedConfiguration
        )

        let persistedData =
            try XCTUnwrap(
                context.userDefaults.data(
                    forKey:
                        StorageKey.configuration
                )
            )

        let reloadedConfiguration =
            try JSONDecoder().decode(
                RemappingProfilesConfiguration.self,
                from:
                    persistedData
            )

        XCTAssertEqual(
            reloadedConfiguration,
            loadedConfiguration
        )

        XCTAssertNil(
            reloadedConfiguration
                .activeProfile?
                .shortcutConfigurationOverride
        )
    }

    func testOverrideEqualToDefaultRemainsExplicitAfterPersistence()
        throws
    {
        let context =
            try makeContext()

        defer {
            context.cleanUp()
        }

        let defaultShortcutConfiguration =
            RemappingShortcutConfiguration.toggle(
                KeyCombination(
                    keyCode:
                        KeyCode.n,
                    modifiers: [
                        .control,
                        .option,
                        .command
                    ]
                )
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    defaultShortcutConfiguration
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    profile
                ],
                activeProfileID:
                    profile.id
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

        let loadedOverride =
            try XCTUnwrap(
                loadedConfiguration
                    .activeProfile?
                    .shortcutConfigurationOverride
            )

        XCTAssertEqual(
            loadedOverride,
            defaultShortcutConfiguration
        )
    }

    private func makeContext()
        throws -> TestContext
    {
        let suiteName =
            "RemappingProfileShortcutOverridePersistenceTests."
            + UUID().uuidString

        let userDefaults =
            try XCTUnwrap(
                UserDefaults(
                    suiteName:
                        suiteName
                )
            )

        userDefaults.removePersistentDomain(
            forName:
                suiteName
        )

        return TestContext(
            suiteName:
                suiteName,
            userDefaults:
                userDefaults
        )
    }

    private struct TestContext {
        let suiteName: String
        let userDefaults: UserDefaults

        func cleanUp() {
            userDefaults.removePersistentDomain(
                forName:
                    suiteName
            )
        }
    }

    private struct LegacyRemappingProfilesConfiguration:
        Codable
    {
        let profiles:
            [LegacyRemappingProfile]

        let activeProfileID:
            UUID
    }

    private struct LegacyRemappingProfile:
        Codable
    {
        let id:
            UUID

        let name:
            String

        let createdAt:
            Date

        let updatedAt:
            Date

        let rules:
            [RemapRule]
    }
}
