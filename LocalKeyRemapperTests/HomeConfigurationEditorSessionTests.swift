//
//  HomeConfigurationEditorSessionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeConfigurationEditorSessionTests:
    XCTestCase
{
    func testInitialSnapshotIsBothSavedBaselineAndCleanDraft() {
        let snapshot =
            makeSnapshot()

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    snapshot
            )

        XCTAssertEqual(
            session.savedSnapshot,
            snapshot
        )
        XCTAssertEqual(
            session.draft,
            snapshot
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )
        XCTAssertFalse(
            session.canUndo
        )
        XCTAssertFalse(
            session.canRedo
        )
        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
    }

    func testLaunchBehaviorChangeIsOneUndoableHomeAction() {
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        launchBehavior:
                            .alwaysOff
                    )
            )

        session.setLaunchBehavior(
            .alwaysOn
        )

        XCTAssertEqual(
            session.draft.launchBehavior,
            .alwaysOn
        )
        XCTAssertTrue(
            session.hasUnsavedChanges
        )
        XCTAssertTrue(
            session.canUndo
        )
        XCTAssertEqual(
            session.historyEntryCount,
            1
        )

        session.undo()

        XCTAssertEqual(
            session.draft.launchBehavior,
            .alwaysOff
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )
        XCTAssertTrue(
            session.canRedo
        )

        session.redo()

        XCTAssertEqual(
            session.draft.launchBehavior,
            .alwaysOn
        )
        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testApplyingSameLaunchBehaviorDoesNotCreateHistory() {
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        launchBehavior:
                            .restoreLastState
                    )
            )

        session.setLaunchBehavior(
            .restoreLastState
        )

        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )
    }

    func testShortcutConfigurationChangeIsUndoableIndependentlyFromRulesHistory() {
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        shortcutConfiguration:
                            .disabled
                    )
            )

        let updatedConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    AppPreferences
                        .defaultToggleShortcut
                )

        session.setShortcutConfiguration(
            updatedConfiguration
        )

        XCTAssertEqual(
            session.draft.shortcutConfiguration,
            updatedConfiguration
        )
        XCTAssertEqual(
            session.historyEntryCount,
            1
        )

        session.undo()

        XCTAssertEqual(
            session.draft.shortcutConfiguration,
            .disabled
        )
    }

    func testAddProfileUsesFirstAvailableExactNumberAndKeepsActiveProfile() throws {
        let firstID =
            fixedUUID(
                "80E3831B-9BB1-41DD-BBE3-A36ACEC0D1A8"
            )
        let thirdID =
            fixedUUID(
                "B56B4AFA-D543-442E-AD86-C1C8EF755924"
            )
        let addedID =
            fixedUUID(
                "E0A06189-709A-430A-8127-F0D3D90411ED"
            )
        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_722_260_000
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    firstID,
                                name:
                                    "Profile 1"
                            ),
                            makeProfile(
                                id:
                                    thirdID,
                                name:
                                    "Profile 3"
                            )
                        ],
                        activeProfileID:
                            firstID
                    )
            )

        let addedProfile =
            try session.addProfile(
                id:
                    addedID,
                timestamp:
                    timestamp
            )

        XCTAssertEqual(
            addedProfile.id,
            addedID
        )
        XCTAssertEqual(
            addedProfile.name,
            "Profile 2"
        )
        XCTAssertEqual(
            addedProfile.createdAt,
            timestamp
        )
        XCTAssertEqual(
            addedProfile.updatedAt,
            timestamp
        )
        XCTAssertTrue(
            addedProfile.rules.isEmpty
        )
        XCTAssertEqual(
            session.draft.profiles.map(
                \.id
            ),
            [
                firstID,
                thirdID,
                addedID
            ]
        )
        XCTAssertEqual(
            session.draft.activeProfileID,
            firstID
        )
        XCTAssertEqual(
            session.historyEntryCount,
            1
        )
    }

    func testAddProfileUndoRedoPreservesUUIDAndOriginalPosition() throws {
        let firstID =
            fixedUUID(
                "879CC0D7-0F1B-49D5-89D3-A97F9E9694E4"
            )
        let addedID =
            fixedUUID(
                "2697CE69-5CBF-4752-912E-A8058E190909"
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    firstID,
                                name:
                                    "Profile 1"
                            )
                        ],
                        activeProfileID:
                            firstID
                    )
            )

        let addedProfile =
            try session.addProfile(
                id:
                    addedID
            )

        session.undo()

        XCTAssertNil(
            session.draft.profile(
                id:
                    addedID
            )
        )

        session.redo()

        XCTAssertEqual(
            session.draft.profiles.last,
            addedProfile
        )
    }

    func testAddProfileRejectsDuplicateUUIDWithoutChangingDraft() {
        let profileID =
            fixedUUID(
                "E2289215-E914-4EE3-AC81-883384EF7868"
            )
        let snapshot =
            makeSnapshot(
                profiles: [
                    makeProfile(
                        id:
                            profileID,
                        name:
                            "Profile 1"
                    )
                ],
                activeProfileID:
                    profileID
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    snapshot
            )

        XCTAssertThrowsError(
            try session.addProfile(
                id:
                    profileID
            )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    HomeConfigurationEditorSessionError,
                .duplicateProfileID(
                    profileID
                )
            )
        }

        XCTAssertEqual(
            session.draft,
            snapshot
        )
        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
    }

    func testDuplicateProfileCopiesCompleteRulesAndUsesIndependentIdentity() throws {
        let sourceID =
            fixedUUID(
                "8392140F-44D9-43B9-9B84-84DC798D3CC7"
            )
        let duplicateID =
            fixedUUID(
                "A18F0564-4124-467D-BE53-41FE817018EC"
            )
        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_722_260_100
            )
        let sourceRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]
        let sourceProfile =
            makeProfile(
                id:
                    sourceID,
                name:
                    "Gaming",
                rules:
                    sourceRules
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            sourceProfile
                        ],
                        activeProfileID:
                            sourceID
                    )
            )

        let duplicate =
            try session.duplicateProfile(
                id:
                    sourceID,
                newProfileID:
                    duplicateID,
                timestamp:
                    timestamp
            )

        XCTAssertEqual(
            duplicate.id,
            duplicateID
        )
        XCTAssertEqual(
            duplicate.name,
            "Gaming Copy"
        )
        XCTAssertEqual(
            duplicate.createdAt,
            timestamp
        )
        XCTAssertEqual(
            duplicate.updatedAt,
            timestamp
        )
        XCTAssertEqual(
            duplicate.rules,
            sourceRules
        )
        XCTAssertEqual(
            session.draft.profiles.map(
                \.id
            ),
            [
                sourceID,
                duplicateID
            ]
        )
        XCTAssertEqual(
            session.draft.activeProfileID,
            sourceID
        )
    }

    func testRepeatedDuplicateNamesIncrementDeterministically() throws {
        let sourceID =
            fixedUUID(
                "91573E12-D9C6-4D8D-B544-0132D00DDE65"
            )
        let firstCopyID =
            fixedUUID(
                "47EDC596-ECA2-466C-B3A8-716785799405"
            )
        let secondCopyID =
            fixedUUID(
                "EE50A249-5207-4253-A9EB-478BFD2D675C"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    sourceID,
                                name:
                                    "Coding"
                            )
                        ],
                        activeProfileID:
                            sourceID
                    )
            )

        let firstCopy =
            try session.duplicateProfile(
                id:
                    sourceID,
                newProfileID:
                    firstCopyID
            )
        let secondCopy =
            try session.duplicateProfile(
                id:
                    sourceID,
                newProfileID:
                    secondCopyID
            )

        XCTAssertEqual(
            firstCopy.name,
            "Coding Copy"
        )
        XCTAssertEqual(
            secondCopy.name,
            "Coding Copy 2"
        )
        XCTAssertEqual(
            session.draft.profiles.map(
                \.id
            ),
            [
                sourceID,
                secondCopyID,
                firstCopyID
            ]
        )
    }

    func testRenamePreservesIdentityCreationDateAndRulesAndIsUndoable() throws {
        let profileID =
            fixedUUID(
                "4E4072D7-F693-4615-9AD3-BF57AE58437F"
            )
        let createdAt =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )
        let originalUpdatedAt =
            Date(
                timeIntervalSince1970:
                    1_710_000_000
            )
        let renamedAt =
            Date(
                timeIntervalSince1970:
                    1_720_000_000
            )
        let rules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            )
        ]
        let originalProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Profile 1",
                createdAt:
                    createdAt,
                updatedAt:
                    originalUpdatedAt,
                rules:
                    rules
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            originalProfile
                        ],
                        activeProfileID:
                            profileID
                    )
            )

        try session.renameProfile(
            id:
                profileID,
            to:
                "Gaming",
            timestamp:
                renamedAt
        )

        let renamedProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        profileID
                )
            )

        XCTAssertEqual(
            renamedProfile.id,
            profileID
        )
        XCTAssertEqual(
            renamedProfile.name,
            "Gaming"
        )
        XCTAssertEqual(
            renamedProfile.createdAt,
            createdAt
        )
        XCTAssertEqual(
            renamedProfile.updatedAt,
            renamedAt
        )
        XCTAssertEqual(
            renamedProfile.rules,
            rules
        )

        session.undo()

        XCTAssertEqual(
            session.draft.profile(
                id:
                    profileID
            ),
            originalProfile
        )
    }

    func testRenameAllowsTemporarilyInvalidDraftNameForLaterSaveValidation() throws {
        let profileID =
            fixedUUID(
                "F414A36B-04C8-4FA2-BCF9-92511F2DCCF0"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    profileID,
                                name:
                                    "Profile 1"
                            )
                        ],
                        activeProfileID:
                            profileID
                    )
            )

        try session.renameProfile(
            id:
                profileID,
            to:
                "   "
        )

        XCTAssertEqual(
            session.draft.profile(
                id:
                    profileID
            )?.name,
            "   "
        )
        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testCannotRemoveFinalRemainingProfile() {
        let profileID =
            fixedUUID(
                "A88E2398-DA0F-451F-A45D-589277D93008"
            )
        let snapshot =
            makeSnapshot(
                profiles: [
                    makeProfile(
                        id:
                            profileID,
                        name:
                            "Profile 1"
                    )
                ],
                activeProfileID:
                    profileID
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    snapshot
            )

        XCTAssertThrowsError(
            try session.removeProfile(
                id:
                    profileID
            )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    HomeConfigurationEditorSessionError,
                .cannotRemoveLastProfile
            )
        }

        XCTAssertEqual(
            session.draft,
            snapshot
        )
        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
    }

    func testCannotRemoveActiveProfileUntilAnotherProfileIsSelected() {
        let activeID =
            fixedUUID(
                "661D58C1-431C-4B99-82A4-E8595477584C"
            )
        let inactiveID =
            fixedUUID(
                "543C6D0F-2584-4094-B10D-D052FD5D0E8E"
            )
        let snapshot =
            makeSnapshot(
                profiles: [
                    makeProfile(
                        id:
                            activeID,
                        name:
                            "Active"
                    ),
                    makeProfile(
                        id:
                            inactiveID,
                        name:
                            "Inactive"
                    )
                ],
                activeProfileID:
                    activeID
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    snapshot
            )

        XCTAssertThrowsError(
            try session.removeProfile(
                id:
                    activeID
            )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    HomeConfigurationEditorSessionError,
                .cannotRemoveActiveProfile(
                    activeID
                )
            )
        }

        XCTAssertEqual(
            session.draft,
            snapshot
        )
        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
    }

    func testRemoveUndoRestoresCompleteProfileAtOriginalIndex() throws {
        let firstID =
            fixedUUID(
                "0042E36E-B3BA-48BD-AF70-37E50FD7554F"
            )
        let removedID =
            fixedUUID(
                "BD60A0F7-C091-4AAE-BBB6-90F15A6C301D"
            )
        let thirdID =
            fixedUUID(
                "CA0510DE-1A71-4C1B-89B8-3902B6A1536F"
            )
        let removedProfile =
            makeProfile(
                id:
                    removedID,
                name:
                    "Gaming",
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ]
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    firstID,
                                name:
                                    "Active"
                            ),
                            removedProfile,
                            makeProfile(
                                id:
                                    thirdID,
                                name:
                                    "Third"
                            )
                        ],
                        activeProfileID:
                            firstID
                    )
            )

        try session.removeProfile(
            id:
                removedID
        )

        XCTAssertEqual(
            session.draft.profiles.map(
                \.id
            ),
            [
                firstID,
                thirdID
            ]
        )

        session.undo()

        XCTAssertEqual(
            session.draft.profiles.map(
                \.id
            ),
            [
                firstID,
                removedID,
                thirdID
            ]
        )
        XCTAssertEqual(
            session.draft.profile(
                id:
                    removedID
            ),
            removedProfile
        )
    }

    func testActiveProfileChangeUpdatesOnlyDraftAndIsUndoable() throws {
        let firstID =
            fixedUUID(
                "9D5DA290-F860-413F-B1CA-2D5C6B441CC5"
            )
        let secondID =
            fixedUUID(
                "29284E7C-6270-416F-9CD7-A22035C5AD6E"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    firstID,
                                name:
                                    "First"
                            ),
                            makeProfile(
                                id:
                                    secondID,
                                name:
                                    "Second"
                            )
                        ],
                        activeProfileID:
                            firstID
                    )
            )

        try session.setActiveProfile(
            secondID
        )

        XCTAssertEqual(
            session.draft.activeProfileID,
            secondID
        )
        XCTAssertEqual(
            session.savedSnapshot.activeProfileID,
            firstID
        )

        session.undo()

        XCTAssertEqual(
            session.draft.activeProfileID,
            firstID
        )

        session.redo()

        XCTAssertEqual(
            session.draft.activeProfileID,
            secondID
        )
    }

    func testInvalidActiveProfileIsRejectedWithoutHistory() {
        let activeID =
            fixedUUID(
                "7AF3E822-A2EC-4F46-A6D4-B1E2F6048D34"
            )
        let missingID =
            fixedUUID(
                "A96F9E64-09C7-4070-B099-4087F8AD9037"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    activeID,
                                name:
                                    "Profile 1"
                            )
                        ],
                        activeProfileID:
                            activeID
                    )
            )

        XCTAssertThrowsError(
            try session.setActiveProfile(
                missingID
            )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    HomeConfigurationEditorSessionError,
                .invalidActiveProfile(
                    missingID
                )
            )
        }

        XCTAssertEqual(
            session.draft.activeProfileID,
            activeID
        )
        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
    }

    func testNewActionAfterUndoClearsRedoBranch() {
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        launchBehavior:
                            .alwaysOff,
                        shortcutConfiguration:
                            .disabled
                    )
            )

        session.setLaunchBehavior(
            .alwaysOn
        )
        session.undo()

        XCTAssertTrue(
            session.canRedo
        )

        session.setShortcutConfiguration(
            .toggle(
                AppPreferences
                    .defaultToggleShortcut
            )
        )

        XCTAssertFalse(
            session.canRedo
        )
        XCTAssertEqual(
            session.historyEntryCount,
            1
        )
    }

    func testSuccessfulSaveUpdatesBaselineWithoutClearingUndo() {
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        launchBehavior:
                            .alwaysOff
                    )
            )

        session.setLaunchBehavior(
            .alwaysOn
        )

        let committedDeletionIDs =
            session.markCurrentDraftAsSaved()

        XCTAssertTrue(
            committedDeletionIDs.isEmpty
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )
        XCTAssertTrue(
            session.canUndo
        )
        XCTAssertEqual(
            session.savedSnapshot.launchBehavior,
            .alwaysOn
        )

        session.undo()

        XCTAssertEqual(
            session.draft.launchBehavior,
            .alwaysOff
        )
        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testSuccessfulSaveReturnsEveryProfileIDWhoseDeletionBecameCommitted() throws {
        let activeID =
            fixedUUID(
                "98BB0BF5-1648-4767-8824-6DB46F5ED089"
            )
        let removedID =
            fixedUUID(
                "643B348B-D68B-4BB8-AF40-3595409A165E"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    activeID,
                                name:
                                    "Active"
                            ),
                            makeProfile(
                                id:
                                    removedID,
                                name:
                                    "Removed"
                            )
                        ],
                        activeProfileID:
                            activeID
                    )
            )

        try session.removeProfile(
            id:
                removedID
        )

        let committedDeletionIDs =
            session.markCurrentDraftAsSaved()

        XCTAssertEqual(
            committedDeletionIDs,
            Set(
                [
                    removedID
                ]
            )
        )
        XCTAssertNil(
            session.savedSnapshot.profile(
                id:
                    removedID
            )
        )
    }

    func testSuccessfulSaveAlsoReturnsUnsavedProfileAddedThenRemovedSincePreviousSave() throws {
        let activeID =
            fixedUUID(
                "B054A282-FF2F-469A-8563-5BC3B079034C"
            )
        let temporaryID =
            fixedUUID(
                "D740F2EE-7454-4C37-B39F-5E9F80D60CF2"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    activeID,
                                name:
                                    "Profile 1"
                            )
                        ],
                        activeProfileID:
                            activeID,
                        launchBehavior:
                            .alwaysOff
                    )
            )

        _ =
            try session.addProfile(
                id:
                    temporaryID
            )
        try session.removeProfile(
            id:
                temporaryID
        )
        session.setLaunchBehavior(
            .alwaysOn
        )

        let committedDeletionIDs =
            session.markCurrentDraftAsSaved()

        XCTAssertEqual(
            committedDeletionIDs,
            Set(
                [
                    temporaryID
                ]
            )
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )
    }

    func testCommittedNormalizedSnapshotBecomesBothDraftAndBaseline() throws {
        let profileID =
            fixedUUID(
                "B7C3C8E0-CF37-44D3-9247-C7784D3EA2C7"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    profileID,
                                name:
                                    "Profile 1"
                            )
                        ],
                        activeProfileID:
                            profileID
                    )
            )

        try session.renameProfile(
            id:
                profileID,
            to:
                "  Gaming  "
        )

        var normalizedSnapshot =
            session.draft
        normalizedSnapshot.profiles[0].name =
            "Gaming"

        session.markCurrentDraftAsSaved(
            normalizedSnapshot
        )

        XCTAssertEqual(
            session.savedSnapshot,
            normalizedSnapshot
        )
        XCTAssertEqual(
            session.draft,
            normalizedSnapshot
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )
        XCTAssertTrue(
            session.canUndo
        )
    }

    func testRestoreSavedSnapshotIsOneReversibleHomeAction() throws {
        let activeID =
            fixedUUID(
                "FF14C87D-0E88-48D9-8A7D-F38A7304D33B"
            )
        let addedID =
            fixedUUID(
                "06281559-C917-4CB5-BF9B-B4BD8C583468"
            )
        let originalSnapshot =
            makeSnapshot(
                profiles: [
                    makeProfile(
                        id:
                            activeID,
                        name:
                            "Profile 1"
                    )
                ],
                activeProfileID:
                    activeID,
                launchBehavior:
                    .alwaysOff
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    originalSnapshot
            )

        _ =
            try session.addProfile(
                id:
                    addedID
            )
        session.setLaunchBehavior(
            .alwaysOn
        )
        let editedSnapshot =
            session.draft

        session.restoreSavedSnapshot()

        XCTAssertEqual(
            session.draft,
            originalSnapshot
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        session.undo()

        XCTAssertEqual(
            session.draft,
            editedSnapshot
        )
        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testOnChangeRunsOnlyForEffectiveStateChanges() throws {
        let profileID =
            fixedUUID(
                "61E37AC6-021B-4645-9D09-3CED099AF9D8"
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    profileID,
                                name:
                                    "Profile 1"
                            )
                        ],
                        activeProfileID:
                            profileID,
                        launchBehavior:
                            .alwaysOff
                    )
            )
        var changeCount =
            0

        session.onChange = {
            changeCount +=
                1
        }

        session.setLaunchBehavior(
            .alwaysOff
        )
        try session.renameProfile(
            id:
                profileID,
            to:
                "Profile 1"
        )

        XCTAssertEqual(
            changeCount,
            0
        )

        session.setLaunchBehavior(
            .alwaysOn
        )
        session.undo()
        session.redo()
        session.markCurrentDraftAsSaved()

        XCTAssertEqual(
            changeCount,
            4
        )
    }

    func testHistoryRespectsMaximumEntryCount() {
        let history =
            HomeConfigurationHistory(
                maximumEntryCount:
                    2,
                maximumEstimatedPayloadSize:
                    .max
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        launchBehavior:
                            .alwaysOff
                    ),
                history:
                    history
            )

        session.setLaunchBehavior(
            .alwaysOn
        )
        session.setLaunchBehavior(
            .restoreLastState
        )
        session.setLaunchBehavior(
            .alwaysOff
        )

        XCTAssertEqual(
            session.historyEntryCount,
            2
        )

        session.undo()
        session.undo()
        session.undo()

        XCTAssertEqual(
            session.draft.launchBehavior,
            .alwaysOn
        )
    }

    func testHistoryDropsEntryThatExceedsPayloadLimit() {
        let history =
            HomeConfigurationHistory(
                maximumEntryCount:
                    .max,
                maximumEstimatedPayloadSize:
                    1
            )
        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        launchBehavior:
                            .alwaysOff
                    ),
                history:
                    history
            )

        session.setLaunchBehavior(
            .alwaysOn
        )

        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
        XCTAssertFalse(
            session.canUndo
        )
        XCTAssertEqual(
            session.draft.launchBehavior,
            .alwaysOn
        )
    }

    private func makeSnapshot(
        profiles:
            [RemappingProfile]? = nil,
        activeProfileID:
            UUID? = nil,
        launchBehavior:
            RemappingLaunchBehavior =
                .alwaysOff,
        shortcutConfiguration:
            RemappingShortcutConfiguration =
                .disabled
    ) -> HomeConfigurationSnapshot {
        let fallbackID =
            fixedUUID(
                "DE917D90-A6E6-45D1-9010-FCD96F059769"
            )
        let resolvedProfiles =
            profiles
                ?? [
                    makeProfile(
                        id:
                            fallbackID,
                        name:
                            "Profile 1"
                    )
                ]
        let resolvedActiveProfileID =
            activeProfileID
                ?? resolvedProfiles
                    .first?
                    .id
                ?? fallbackID

        return HomeConfigurationSnapshot(
            profilesConfiguration:
                RemappingProfilesConfiguration(
                    profiles:
                        resolvedProfiles,
                    activeProfileID:
                        resolvedActiveProfileID
                ),
            launchBehavior:
                launchBehavior,
            shortcutConfiguration:
                shortcutConfiguration
        )
    }

    private func makeProfile(
        id:
            UUID,
        name:
            String,
        createdAt:
            Date = Date(
                timeIntervalSince1970:
                    1_700_000_000
            ),
        updatedAt:
            Date? = nil,
        rules:
            [RemapRule] = []
    ) -> RemappingProfile {
        RemappingProfile(
            id:
                id,
            name:
                name,
            createdAt:
                createdAt,
            updatedAt:
                updatedAt,
            rules:
                rules
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
