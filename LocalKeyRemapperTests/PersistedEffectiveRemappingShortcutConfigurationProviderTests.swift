//
//  PersistedEffectiveRemappingShortcutConfigurationProviderTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class PersistedEffectiveRemappingShortcutConfigurationProviderTests:
    XCTestCase
{
    func testUseDefaultProfileResolvesCurrentDefault()
        throws
    {
        let defaultConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    nil
            )

        let store =
            makeStore(
                profile:
                    profile
            )

        let provider =
            PersistedEffectiveRemappingShortcutConfigurationProvider(
                profilesStore:
                    store,
                defaultConfigurationProvider: {
                    defaultConfiguration
                }
            )

        XCTAssertEqual(
            try provider.configuration(),
            defaultConfiguration
        )
    }

    func testExplicitOffProfileDoesNotUseEnabledDefault()
        throws
    {
        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .disabled
            )

        let store =
            makeStore(
                profile:
                    profile
            )

        let provider =
            PersistedEffectiveRemappingShortcutConfigurationProvider(
                profilesStore:
                    store,
                defaultConfigurationProvider: {
                    self.makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
                }
            )

        XCTAssertEqual(
            try provider.configuration(),
            .disabled
        )
    }

    func testCustomProfileOverrideReplacesDefault()
        throws
    {
        let customConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    customConfiguration
            )

        let store =
            makeStore(
                profile:
                    profile
            )

        let provider =
            PersistedEffectiveRemappingShortcutConfigurationProvider(
                profilesStore:
                    store,
                defaultConfigurationProvider: {
                    self.makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
                }
            )

        XCTAssertEqual(
            try provider.configuration(),
            customConfiguration
        )
    }

    func testMissingPersistedActiveProfileIsSurfaced() {
        let existingProfile =
            RemappingProfile(
                id:
                    fixedUUID(
                        "7BFEDC7B-5C66-40AA-B411-902717891982"
                    ),
                name:
                    "Existing"
            )

        let missingProfileID =
            fixedUUID(
                "BE8559B8-E00F-42CD-8C13-1308E40CC004"
            )

        let store =
            PersistedEffectiveShortcutProfilesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            existingProfile
                        ],
                        activeProfileID:
                            missingProfileID
                    )
            )

        let provider =
            PersistedEffectiveRemappingShortcutConfigurationProvider(
                profilesStore:
                    store,
                defaultConfigurationProvider: {
                    .disabled
                }
            )

        XCTAssertThrowsError(
            try provider.configuration()
        ) {
            error in

            XCTAssertEqual(
                error as?
                    RemappingProfilesConfigurationValidationError,
                .missingActiveProfile(
                    missingProfileID
                )
            )
        }
    }

    func testEveryResolutionReloadsProfilesAndCurrentDefault()
        throws
    {
        let profileID =
            fixedUUID(
                "AC304E59-92D4-4870-81A3-35A362485FD7"
            )

        var currentDefault =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let useDefaultProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    nil
            )

        let store =
            makeStore(
                profile:
                    useDefaultProfile
            )

        let provider =
            PersistedEffectiveRemappingShortcutConfigurationProvider(
                profilesStore:
                    store,
                defaultConfigurationProvider: {
                    currentDefault
                }
            )

        XCTAssertEqual(
            try provider.configuration(),
            currentDefault
        )

        let customConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.r
            )

        var customProfile =
            useDefaultProfile

        customProfile.shortcutConfigurationOverride =
            customConfiguration

        store.replaceConfiguration(
            RemappingProfilesConfiguration(
                profiles: [
                    customProfile
                ],
                activeProfileID:
                    profileID
            )
        )

        XCTAssertEqual(
            try provider.configuration(),
            customConfiguration
        )

        currentDefault =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.e
            )

        var restoredUseDefaultProfile =
            customProfile

        restoredUseDefaultProfile
            .shortcutConfigurationOverride =
                nil

        store.replaceConfiguration(
            RemappingProfilesConfiguration(
                profiles: [
                    restoredUseDefaultProfile
                ],
                activeProfileID:
                    profileID
            )
        )

        XCTAssertEqual(
            try provider.configuration(),
            currentDefault
        )

        XCTAssertEqual(
            store.loadCallCount,
            3
        )
    }

    private func makeStore(
        profile:
            RemappingProfile
    ) -> PersistedEffectiveShortcutProfilesStore {
        PersistedEffectiveShortcutProfilesStore(
            configuration:
                RemappingProfilesConfiguration(
                    profiles: [
                        profile
                    ],
                    activeProfileID:
                        profile.id
                )
        )
    }

    private func makeToggleConfiguration(
        keyCode:
            CGKeyCode
    ) -> RemappingShortcutConfiguration {
        .toggle(
            KeyCombination(
                keyCode:
                    keyCode,
                modifiers: [
                    .control,
                    .option,
                    .command
                ]
            )
        )
    }

    private func fixedUUID(
        _ value:
            String
    ) -> UUID {
        UUID(
            uuidString:
                value
        )!
    }
}

@MainActor
private final class PersistedEffectiveShortcutProfilesStore:
    RemappingProfilesStore
{
    private var configuration:
        RemappingProfilesConfiguration

    private(set) var loadCallCount =
        0

    init(
        configuration:
            RemappingProfilesConfiguration
    ) {
        self.configuration =
            configuration
    }

    func loadConfiguration()
        throws -> RemappingProfilesConfiguration
    {
        loadCallCount +=
            1

        return configuration
    }

    func saveConfiguration(
        _ configuration:
            RemappingProfilesConfiguration
    ) throws {
        self.configuration =
            configuration
    }

    func replaceConfiguration(
        _ configuration:
            RemappingProfilesConfiguration
    ) {
        self.configuration =
            configuration
    }
}
