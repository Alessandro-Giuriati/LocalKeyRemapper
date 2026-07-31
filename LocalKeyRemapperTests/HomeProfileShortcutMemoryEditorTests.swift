//
//  HomeProfileShortcutMemoryEditorTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeProfileShortcutMemoryEditorTests:
    XCTestCase
{
    func testApplyingToggleUpdatesOnlyToggleMemoryAndIsUndoable()
        throws
    {
        let profileID =
            fixedUUID(
                "FD47686A-E57B-46B5-A210-C34E02783DF7"
            )

        let originalTimestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let changedTimestamp =
            Date(
                timeIntervalSince1970:
                    1_710_000_000
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

        let updatedToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let originalMemory =
            RemappingProfileShortcutMemory(
                enableShortcut:
                    rememberedEnable,
                disableShortcut:
                    rememberedDisable
            )

        let profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                createdAt:
                    originalTimestamp,
                updatedAt:
                    originalTimestamp,
                shortcutConfigurationOverride:
                    nil,
                shortcutMemory:
                    originalMemory
            )

        let session =
            makeSession(
                profile:
                    profile
            )

        try session
            .setShortcutConfigurationOverride(
                .toggle(
                    updatedToggle
                ),
                for:
                    profileID,
                timestamp:
                    changedTimestamp
            )

        let changedProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        profileID
                )
            )

        XCTAssertEqual(
            changedProfile
                .shortcutConfigurationOverride,
            .toggle(
                updatedToggle
            )
        )

        XCTAssertEqual(
            changedProfile
                .shortcutMemory
                .toggleShortcut,
            updatedToggle
        )

        XCTAssertEqual(
            changedProfile
                .shortcutMemory
                .enableShortcut,
            rememberedEnable
        )

        XCTAssertEqual(
            changedProfile
                .shortcutMemory
                .disableShortcut,
            rememberedDisable
        )

        XCTAssertEqual(
            changedProfile.updatedAt,
            changedTimestamp
        )

        XCTAssertEqual(
            session.historyEntryCount,
            1
        )

        session.undo()

        let undoneProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        profileID
                )
            )

        XCTAssertNil(
            undoneProfile
                .shortcutConfigurationOverride
        )

        XCTAssertEqual(
            undoneProfile.shortcutMemory,
            originalMemory
        )

        XCTAssertEqual(
            undoneProfile.updatedAt,
            originalTimestamp
        )

        session.redo()

        let redoneProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        profileID
                )
            )

        XCTAssertEqual(
            redoneProfile
                .shortcutConfigurationOverride,
            .toggle(
                updatedToggle
            )
        )

        XCTAssertEqual(
            redoneProfile
                .shortcutMemory
                .toggleShortcut,
            updatedToggle
        )
    }

    func testSwitchingToOffPreservesEveryRememberedShortcut()
        throws
    {
        let profileID =
            fixedUUID(
                "04B11B38-8695-4E2E-9BB1-F2061CB915E4"
            )

        let memory =
            completeMemory()

        let profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .toggle(
                        try XCTUnwrap(
                            memory.toggleShortcut
                        )
                    ),
                shortcutMemory:
                    memory
            )

        let session =
            makeSession(
                profile:
                    profile
            )

        try session
            .setShortcutConfigurationOverride(
                .disabled,
                for:
                    profileID
            )

        let changedProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        profileID
                )
            )

        XCTAssertEqual(
            changedProfile
                .shortcutConfigurationOverride,
            .disabled
        )

        XCTAssertEqual(
            changedProfile.shortcutMemory,
            memory
        )

        session.undo()

        XCTAssertEqual(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .shortcutMemory,
            memory
        )

        session.redo()

        XCTAssertEqual(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .shortcutMemory,
            memory
        )
    }

    func testSwitchingToUseDefaultPreservesEveryRememberedShortcut()
        throws
    {
        let profileID =
            fixedUUID(
                "8A89B540-8BCB-4997-B506-020B5B39A2E9"
            )

        let memory =
            completeMemory()

        let profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            try XCTUnwrap(
                                memory.enableShortcut
                            ),
                        disable:
                            try XCTUnwrap(
                                memory.disableShortcut
                            )
                    ),
                shortcutMemory:
                    memory
            )

        let session =
            makeSession(
                profile:
                    profile
            )

        try session
            .setShortcutConfigurationOverride(
                nil,
                for:
                    profileID
            )

        let changedProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        profileID
                )
            )

        XCTAssertNil(
            changedProfile
                .shortcutConfigurationOverride
        )

        XCTAssertEqual(
            changedProfile.shortcutMemory,
            memory
        )
    }

    func testDuplicateCopiesShortcutMemory()
        throws
    {
        let sourceProfileID =
            fixedUUID(
                "B451EE6D-1231-4676-9E7D-E799B3C88D72"
            )

        let duplicateProfileID =
            fixedUUID(
                "DD8893D8-4BEC-4BE4-B2FE-B1A05E782B99"
            )

        let memory =
            completeMemory()

        let sourceProfile =
            RemappingProfile(
                id:
                    sourceProfileID,
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .disabled,
                shortcutMemory:
                    memory
            )

        let session =
            makeSession(
                profile:
                    sourceProfile
            )

        let duplicate =
            try session.duplicateProfile(
                id:
                    sourceProfileID,
                newProfileID:
                    duplicateProfileID
            )

        XCTAssertEqual(
            duplicate
                .shortcutConfigurationOverride,
            .disabled
        )

        XCTAssertEqual(
            duplicate.shortcutMemory,
            memory
        )

        session.undo()

        XCTAssertNil(
            session.draft.profile(
                id:
                    duplicateProfileID
            )
        )

        session.redo()

        XCTAssertEqual(
            session.draft
                .profile(
                    id:
                        duplicateProfileID
                )?
                .shortcutMemory,
            memory
        )
    }

    func testMergerUsesHomeShortcutMemoryAndLatestPersistedRules() {
        let profileID =
            fixedUUID(
                "4009E692-EC6F-4333-A2B5-926C1F7F0CFA"
            )

        let homeMemory =
            completeMemory()

        let draftProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming Renamed",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            1_700_000_100
                    ),
                updatedAt:
                    Date(
                        timeIntervalSince1970:
                            1_710_000_000
                    ),
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ],
                shortcutConfigurationOverride:
                    .disabled,
                shortcutMemory:
                    homeMemory
            )

        let persistedRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.b,
                destinationKeyCode:
                    KeyCode.j
            )
        ]

        let persistedProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            1_690_000_000
                    ),
                updatedAt:
                    Date(
                        timeIntervalSince1970:
                            1_720_000_000
                    ),
                rules:
                    persistedRules,
                shortcutConfigurationOverride:
                    nil,
                shortcutMemory:
                    .empty
            )

        let merged =
            HomeProfilesConfigurationMerger
                .merging(
                    homeDraft:
                        RemappingProfilesConfiguration(
                            profiles: [
                                draftProfile
                            ],
                            activeProfileID:
                                profileID
                        ),
                    persisted:
                        RemappingProfilesConfiguration(
                            profiles: [
                                persistedProfile
                            ],
                            activeProfileID:
                                profileID
                        )
                )

        let mergedProfile =
            merged.profiles[0]

        XCTAssertEqual(
            mergedProfile.name,
            "Gaming Renamed"
        )

        XCTAssertEqual(
            mergedProfile.createdAt,
            persistedProfile.createdAt
        )

        XCTAssertEqual(
            mergedProfile.updatedAt,
            persistedProfile.updatedAt
        )

        XCTAssertEqual(
            mergedProfile.rules,
            persistedRules
        )

        XCTAssertEqual(
            mergedProfile
                .shortcutConfigurationOverride,
            .disabled
        )

        XCTAssertEqual(
            mergedProfile.shortcutMemory,
            homeMemory
        )
    }

    func testSavedBaselineAndRestorePreserveShortcutMemory()
        throws
    {
        let profileID =
            fixedUUID(
                "6AF86A09-5B6C-4EAF-B740-3E1689025044"
            )

        let profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming"
            )

        let session =
            makeSession(
                profile:
                    profile
            )

        let toggleShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        try session
            .setShortcutConfigurationOverride(
                .toggle(
                    toggleShortcut
                ),
                for:
                    profileID
            )

        _ =
            session.markCurrentDraftAsSaved()

        XCTAssertEqual(
            session.savedSnapshot
                .profile(
                    id:
                        profileID
                )?
                .shortcutMemory
                .toggleShortcut,
            toggleShortcut
        )

        try session
            .setShortcutConfigurationOverride(
                .disabled,
                for:
                    profileID
            )

        session.restoreSavedSnapshot()

        XCTAssertEqual(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .shortcutConfigurationOverride,
            .toggle(
                toggleShortcut
            )
        )

        XCTAssertEqual(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .shortcutMemory
                .toggleShortcut,
            toggleShortcut
        )
    }

    private func makeSession(
        profile:
            RemappingProfile
    ) -> HomeConfigurationEditorSession {
        HomeConfigurationEditorSession(
            snapshot:
                HomeConfigurationSnapshot(
                    profilesConfiguration:
                        RemappingProfilesConfiguration(
                            profiles: [
                                profile
                            ],
                            activeProfileID:
                                profile.id
                        ),
                    launchBehavior:
                        .alwaysOff,
                    shortcutConfiguration:
                        .disabled
                )
        )
    }

    private func completeMemory()
        -> RemappingProfileShortcutMemory
    {
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
