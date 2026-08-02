//
//  RemappingProfileShortcutMemoryTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class RemappingProfileShortcutMemoryTests:
    XCTestCase
{
    func testUseDefaultAndOffCreateEmptyInitialMemory() {
        XCTAssertEqual(
            RemappingProfileShortcutMemory(
                shortcutConfiguration:
                    nil
            ),
            .empty
        )

        XCTAssertEqual(
            RemappingProfileShortcutMemory(
                shortcutConfiguration:
                    .disabled
            ),
            .empty
        )
    }

    func testToggleOverrideSeedsToggleMemory() {
        let toggleShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .toggle(
                        toggleShortcut
                    )
            )

        XCTAssertEqual(
            profile
                .shortcutMemory
                .toggleShortcut,
            toggleShortcut
        )

        XCTAssertNil(
            profile
                .shortcutMemory
                .enableShortcut
        )

        XCTAssertNil(
            profile
                .shortcutMemory
                .disableShortcut
        )
    }

    func testSeparateOverrideSeedsEnableAndDisableMemory() {
        let enableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let disableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            enableShortcut,
                        disable:
                            disableShortcut
                    )
            )

        XCTAssertNil(
            profile
                .shortcutMemory
                .toggleShortcut
        )

        XCTAssertEqual(
            profile
                .shortcutMemory
                .enableShortcut,
            enableShortcut
        )

        XCTAssertEqual(
            profile
                .shortcutMemory
                .disableShortcut,
            disableShortcut
        )
    }

    func testRememberingTogglePreservesSeparateValues() {
        let originalEnable =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let originalDisable =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let updatedToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let originalMemory =
            RemappingProfileShortcutMemory(
                toggleShortcut:
                    makeShortcut(
                        keyCode:
                            KeyCode.n
                    ),
                enableShortcut:
                    originalEnable,
                disableShortcut:
                    originalDisable
            )

        let updatedMemory =
            originalMemory.remembering(
                .toggle(
                    updatedToggle
                )
            )

        XCTAssertEqual(
            updatedMemory.toggleShortcut,
            updatedToggle
        )

        XCTAssertEqual(
            updatedMemory.enableShortcut,
            originalEnable
        )

        XCTAssertEqual(
            updatedMemory.disableShortcut,
            originalDisable
        )
    }

    func testRememberingSeparatePreservesToggleValue() {
        let originalToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let updatedEnable =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let updatedDisable =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let originalMemory =
            RemappingProfileShortcutMemory(
                toggleShortcut:
                    originalToggle
            )

        let updatedMemory =
            originalMemory.remembering(
                .separate(
                    enable:
                        updatedEnable,
                    disable:
                        updatedDisable
                )
            )

        XCTAssertEqual(
            updatedMemory.toggleShortcut,
            originalToggle
        )

        XCTAssertEqual(
            updatedMemory.enableShortcut,
            updatedEnable
        )

        XCTAssertEqual(
            updatedMemory.disableShortcut,
            updatedDisable
        )
    }

    func testUseDefaultAndOffDoNotClearExistingMemory() {
        let originalMemory =
            RemappingProfileShortcutMemory(
                toggleShortcut:
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    ),
                enableShortcut:
                    makeShortcut(
                        keyCode:
                            KeyCode.e
                    ),
                disableShortcut:
                    makeShortcut(
                        keyCode:
                            KeyCode.d
                    )
            )

        XCTAssertEqual(
            originalMemory.remembering(
                nil
            ),
            originalMemory
        )

        XCTAssertEqual(
            originalMemory.remembering(
                .disabled
            ),
            originalMemory
        )
    }

    func testDecodingProfileWithoutMemorySeedsFromExistingOverride()
        throws
    {
        let toggleShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let legacyProfile =
            ProfilePayloadBeforeShortcutMemory(
                id:
                    UUID(
                        uuidString:
                            "08B94744-E5FC-4865-B07D-C2B0D9274975"
                    )!,
                name:
                    "Legacy Profile",
                createdAt:
                    timestamp,
                updatedAt:
                    timestamp,
                rules:
                    [],
                shortcutConfigurationOverride:
                    .toggle(
                        toggleShortcut
                    )
            )

        let data =
            try JSONEncoder().encode(
                legacyProfile
            )

        let decodedProfile =
            try JSONDecoder().decode(
                RemappingProfile.self,
                from:
                    data
            )

        XCTAssertEqual(
            decodedProfile
                .shortcutConfigurationOverride,
            .toggle(
                toggleShortcut
            )
        )

        XCTAssertEqual(
            decodedProfile
                .shortcutMemory
                .toggleShortcut,
            toggleShortcut
        )
    }

    func testStorePersistsMemoryWhileCurrentOverrideIsOff()
        throws
    {
        let suiteName =
            "RemappingProfileShortcutMemoryTests."
            + UUID().uuidString

        let userDefaults =
            try XCTUnwrap(
                UserDefaults(
                    suiteName:
                        suiteName
                )
            )

        defer {
            userDefaults.removePersistentDomain(
                forName:
                    suiteName
            )
        }

        userDefaults.removePersistentDomain(
            forName:
                suiteName
        )

        let rememberedToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rememberedEnable =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let rememberedDisable =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .disabled,
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        toggleShortcut:
                            rememberedToggle,
                        enableShortcut:
                            rememberedEnable,
                        disableShortcut:
                            rememberedDisable
                    )
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
                    userDefaults
            )

        try store.saveConfiguration(
            configuration
        )

        let loadedConfiguration =
            try store.loadConfiguration()

        let loadedProfile =
            try XCTUnwrap(
                loadedConfiguration
                    .activeProfile
            )

        XCTAssertEqual(
            loadedProfile
                .shortcutConfigurationOverride,
            .disabled
        )

        XCTAssertEqual(
            loadedProfile
                .shortcutMemory
                .toggleShortcut,
            rememberedToggle
        )

        XCTAssertEqual(
            loadedProfile
                .shortcutMemory
                .enableShortcut,
            rememberedEnable
        )

        XCTAssertEqual(
            loadedProfile
                .shortcutMemory
                .disableShortcut,
            rememberedDisable
        )
    }

    private func makeShortcut(
        keyCode:
            CGKeyCode
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }

    private struct ProfilePayloadBeforeShortcutMemory:
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

        let shortcutConfigurationOverride:
            RemappingShortcutConfiguration?
    }
}
