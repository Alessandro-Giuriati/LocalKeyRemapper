//
//  HomeProfileShortcutOverrideEditorTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeProfileShortcutOverrideEditorTests:
    XCTestCase
{
    func testProfileShortcutOverrideChangeIsOneUndoableAction()
        throws
    {
        let profileID =
            fixedUUID(
                "8D3FD35A-0E38-4758-B689-EA14289823D7"
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
                    nil
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profileID
                    )
            )

        let shortcutOverride =
            makeToggleConfiguration()

        try session
            .setShortcutConfigurationOverride(
                shortcutOverride,
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
            shortcutOverride
        )

        XCTAssertEqual(
            changedProfile.updatedAt,
            changedTimestamp
        )

        XCTAssertEqual(
            session.historyEntryCount,
            1
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
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
            undoneProfile.updatedAt,
            originalTimestamp
        )

        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        XCTAssertTrue(
            session.canRedo
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
            shortcutOverride
        )

        XCTAssertEqual(
            redoneProfile.updatedAt,
            changedTimestamp
        )
    }

    func testApplyingSameProfileOverrideDoesNotCreateHistory()
        throws
    {
        let profileID =
            fixedUUID(
                "42FD7C9F-F28F-4033-91D1-0D030DB220A2"
            )

        let originalTimestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
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
                    .disabled
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profileID
                    )
            )

        try session
            .setShortcutConfigurationOverride(
                .disabled,
                for:
                    profileID,
                timestamp:
                    originalTimestamp
                        .addingTimeInterval(
                            500
                        )
            )

        XCTAssertEqual(
            session.historyEntryCount,
            0
        )

        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        XCTAssertEqual(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .updatedAt,
            originalTimestamp
        )
    }

    func testOverrideEqualToDefaultRemainsExplicit()
        throws
    {
        let profileID =
            fixedUUID(
                "9B462BC4-73A9-4BA5-AD9A-FB871B8DEBB2"
            )

        let defaultConfiguration =
            makeToggleConfiguration()

        let profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming"
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profileID,
                        defaultShortcutConfiguration:
                            defaultConfiguration
                    )
            )

        try session
            .setShortcutConfigurationOverride(
                defaultConfiguration,
                for:
                    profileID
            )

        let storedOverride =
            try XCTUnwrap(
                session.draft
                    .profile(
                        id:
                            profileID
                    )?
                    .shortcutConfigurationOverride
            )

        XCTAssertEqual(
            storedOverride,
            defaultConfiguration
        )

        XCTAssertEqual(
            session.draft
                .shortcutConfiguration,
            defaultConfiguration
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testDuplicateProfileCopiesShortcutOverrideAndUndoRedoPreservesIt()
        throws
    {
        let sourceProfileID =
            fixedUUID(
                "975BF63F-0B58-4351-9291-73EBBB8A9091"
            )

        let duplicateProfileID =
            fixedUUID(
                "5F08C1D9-7497-4884-A64A-F63D9855E340"
            )

        let duplicateTimestamp =
            Date(
                timeIntervalSince1970:
                    1_720_000_000
            )

        let shortcutOverride =
            RemappingShortcutConfiguration
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

        let sourceProfile =
            RemappingProfile(
                id:
                    sourceProfileID,
                name:
                    "Gaming",
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ],
                shortcutConfigurationOverride:
                    shortcutOverride
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            sourceProfile
                        ],
                        activeProfileID:
                            sourceProfileID
                    )
            )

        let duplicate =
            try session.duplicateProfile(
                id:
                    sourceProfileID,
                newProfileID:
                    duplicateProfileID,
                timestamp:
                    duplicateTimestamp
            )

        XCTAssertEqual(
            duplicate
                .shortcutConfigurationOverride,
            shortcutOverride
        )

        XCTAssertEqual(
            duplicate.rules,
            sourceProfile.rules
        )

        XCTAssertEqual(
            duplicate.createdAt,
            duplicateTimestamp
        )

        XCTAssertEqual(
            duplicate.updatedAt,
            duplicateTimestamp
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
                .shortcutConfigurationOverride,
            shortcutOverride
        )
    }

    func testMergerUsesHomeOverrideAndLatestPersistedRules() {
        let profileID =
            fixedUUID(
                "99330A58-F0B9-4FC2-A6B2-AD46B32DE926"
            )

        let originalCreationDate =
            Date(
                timeIntervalSince1970:
                    1_690_000_000
            )

        let draftUpdateDate =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let persistedUpdateDate =
            Date(
                timeIntervalSince1970:
                    1_710_000_000
            )

        let draftOverride =
            makeToggleConfiguration()

        let draftProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming Renamed",
                createdAt:
                    originalCreationDate
                        .addingTimeInterval(
                            100
                        ),
                updatedAt:
                    draftUpdateDate,
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ],
                shortcutConfigurationOverride:
                    draftOverride
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
                    originalCreationDate,
                updatedAt:
                    persistedUpdateDate,
                rules:
                    persistedRules,
                shortcutConfigurationOverride:
                    .disabled
            )

        let mergedConfiguration =
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
            mergedConfiguration
                .profiles[0]

        XCTAssertEqual(
            mergedProfile.name,
            "Gaming Renamed"
        )

        XCTAssertEqual(
            mergedProfile.createdAt,
            originalCreationDate
        )

        XCTAssertEqual(
            mergedProfile.updatedAt,
            persistedUpdateDate
        )

        XCTAssertEqual(
            mergedProfile.rules,
            persistedRules
        )

        XCTAssertEqual(
            mergedProfile
                .shortcutConfigurationOverride,
            draftOverride
        )
    }

    func testRestoreSavedSnapshotRestoresProfileOverrideAndCanBeUndone()
        throws
    {
        let profileID =
            fixedUUID(
                "B08C8B1D-EFC8-40FE-A27A-82E33478BAC2"
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            RemappingProfile(
                                id:
                                    profileID,
                                name:
                                    "Gaming"
                            )
                        ],
                        activeProfileID:
                            profileID
                    )
            )

        let shortcutOverride =
            makeToggleConfiguration()

        try session
            .setShortcutConfigurationOverride(
                shortcutOverride,
                for:
                    profileID
            )

        session.restoreSavedSnapshot()

        XCTAssertNil(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .shortcutConfigurationOverride
        )

        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        session.undo()

        XCTAssertEqual(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .shortcutConfigurationOverride,
            shortcutOverride
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testSavingOverrideKeepsUndoHistoryAndUndoMakesHomeDirty()
        throws
    {
        let profileID =
            fixedUUID(
                "F507B75F-ED14-47CD-862D-E7FB7DA008C5"
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            RemappingProfile(
                                id:
                                    profileID,
                                name:
                                    "Gaming"
                            )
                        ],
                        activeProfileID:
                            profileID
                    )
            )

        let shortcutOverride =
            makeToggleConfiguration()

        try session
            .setShortcutConfigurationOverride(
                shortcutOverride,
                for:
                    profileID
            )

        _ =
            session.markCurrentDraftAsSaved()

        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        XCTAssertEqual(
            session.savedSnapshot
                .profile(
                    id:
                        profileID
                )?
                .shortcutConfigurationOverride,
            shortcutOverride
        )

        XCTAssertTrue(
            session.canUndo
        )

        session.undo()

        XCTAssertNil(
            session.draft
                .profile(
                    id:
                        profileID
                )?
                .shortcutConfigurationOverride
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    private func makeSnapshot(
        profiles:
            [RemappingProfile],
        activeProfileID:
            UUID,
        defaultShortcutConfiguration:
            RemappingShortcutConfiguration = .disabled
    ) -> HomeConfigurationSnapshot {
        HomeConfigurationSnapshot(
            profilesConfiguration:
                RemappingProfilesConfiguration(
                    profiles:
                        profiles,
                    activeProfileID:
                        activeProfileID
                ),
            launchBehavior:
                .alwaysOff,
            shortcutConfiguration:
                defaultShortcutConfiguration
        )
    }

    private func makeToggleConfiguration()
        -> RemappingShortcutConfiguration
    {
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
