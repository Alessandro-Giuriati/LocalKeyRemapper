//
//  ImmediateProfileSelectionTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 8/2/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ImmediateProfileSelectionTests:
    XCTestCase
{
    private enum TestFailure:
        Error
    {
        case activationFailed
    }

    func testSuccessfulImmediateActivationSynchronizesSavedAndDraftState() throws {
        let firstID =
            fixedUUID(
                "6EAE6D72-B44F-45D4-B799-1B449F9590FD"
            )

        let secondID =
            fixedUUID(
                "47C10572-E60A-4202-85E3-43884BE919C7"
            )

        let session =
            makeSession(
                firstID:
                    firstID,
                secondID:
                    secondID
            )

        var requestedProfileID:
            UUID?

        var committedProfileID:
            UUID?

        session.onActiveProfileChangeRequested = {
            profileID in

            requestedProfileID =
                profileID
        }

        session.onImmediateActiveProfileChangeCommitted = {
            committedProfileID =
                session
                    .draft
                    .activeProfileID
        }

        try session.setActiveProfile(
            secondID
        )

        XCTAssertEqual(
            requestedProfileID,
            secondID
        )

        XCTAssertEqual(
            committedProfileID,
            secondID
        )

        XCTAssertEqual(
            session
                .draft
                .activeProfileID,
            secondID
        )

        XCTAssertEqual(
            session
                .savedSnapshot
                .activeProfileID,
            secondID
        )

        XCTAssertFalse(
            session
                .hasUnsavedChanges
        )

        XCTAssertEqual(
            session
                .historyEntryCount,
            0
        )
    }

    func testImmediateActivationPreservesUnrelatedUnsavedHomeChanges() throws {
        let firstID =
            fixedUUID(
                "F95D794D-9AC9-4CD4-B3E0-CF3F40673A6C"
            )

        let secondID =
            fixedUUID(
                "236F6049-F492-48C8-9491-D3AA43616C69"
            )

        let session =
            makeSession(
                firstID:
                    firstID,
                secondID:
                    secondID
            )

        try session.renameProfile(
            id:
                firstID,
            to:
                "Unsaved Rename"
        )

        session.onActiveProfileChangeRequested = {
            _ in
        }

        try session.setActiveProfile(
            secondID
        )

        XCTAssertEqual(
            session
                .draft
                .profile(
                    id:
                        firstID
                )?
                .name,
            "Unsaved Rename"
        )

        XCTAssertEqual(
            session
                .savedSnapshot
                .profile(
                    id:
                        firstID
                )?
                .name,
            "Profile 1"
        )

        XCTAssertEqual(
            session
                .draft
                .activeProfileID,
            secondID
        )

        XCTAssertEqual(
            session
                .savedSnapshot
                .activeProfileID,
            secondID
        )

        XCTAssertTrue(
            session
                .hasUnsavedChanges
        )

        XCTAssertEqual(
            session
                .historyEntryCount,
            1
        )
    }

    func testDraftOnlyProfileCannotBecomeActiveBeforeHomeSave() throws {
        let firstID =
            fixedUUID(
                "652DCCB1-F4C0-4514-9E1D-F74F4EDFB8B2"
            )

        let secondID =
            fixedUUID(
                "50C3028C-8749-450C-AC85-B79252A433B5"
            )

        let draftOnlyID =
            fixedUUID(
                "3A23FD1B-B7AB-4ECC-9B49-D62C838E0CF1"
            )

        let session =
            makeSession(
                firstID:
                    firstID,
                secondID:
                    secondID
            )

        _ =
            try session.addProfile(
                id:
                    draftOnlyID
            )

        var activationWasRequested =
            false

        session.onActiveProfileChangeRequested = {
            _ in

            activationWasRequested =
                true
        }

        XCTAssertThrowsError(
            try session.setActiveProfile(
                draftOnlyID
            )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    HomeConfigurationEditorSessionError,
                .profileNotPersisted(
                    draftOnlyID
                )
            )
        }

        XCTAssertFalse(
            activationWasRequested
        )

        XCTAssertEqual(
            session
                .draft
                .activeProfileID,
            firstID
        )

        XCTAssertEqual(
            session
                .savedSnapshot
                .activeProfileID,
            firstID
        )
    }

    func testActivationFailurePreservesPreviousProfileAndDraft() {
        let firstID =
            fixedUUID(
                "5422A93F-7B0B-43C4-AF2B-B5D2B1AF71A4"
            )

        let secondID =
            fixedUUID(
                "AE5AB2B6-1DFB-4DBD-A8A6-97CCF05CFA31"
            )

        let session =
            makeSession(
                firstID:
                    firstID,
                secondID:
                    secondID
            )

        session.onActiveProfileChangeRequested = {
            _ in

            throw TestFailure
                .activationFailed
        }

        XCTAssertThrowsError(
            try session.setActiveProfile(
                secondID
            )
        )

        XCTAssertEqual(
            session
                .draft
                .activeProfileID,
            firstID
        )

        XCTAssertEqual(
            session
                .savedSnapshot
                .activeProfileID,
            firstID
        )

        XCTAssertFalse(
            session
                .hasUnsavedChanges
        )
    }

    func testUndoCannotRemoveTheImmediatelyActiveProfile() throws {
        let firstID =
            fixedUUID(
                "8EBD5F31-A567-4860-9E3B-B6D99DB91062"
            )

        let addedID =
            fixedUUID(
                "6E36BB15-F0F7-4A86-A7ED-00BC53F9698B"
            )

        let initialProfile =
            RemappingProfile(
                id:
                    firstID,
                name:
                    "Profile 1"
            )

        let initialSnapshot =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            initialProfile
                        ],
                        activeProfileID:
                            firstID
                    ),
                launchBehavior:
                    .alwaysOff,
                shortcutConfiguration:
                    .disabled
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    initialSnapshot
            )

        _ =
            try session.addProfile(
                id:
                    addedID
            )

        session.markCurrentDraftAsSaved()

        session.onActiveProfileChangeRequested = {
            _ in
        }

        try session.setActiveProfile(
            addedID
        )

        session.undo()

        XCTAssertNotNil(
            session
                .draft
                .profile(
                    id:
                        addedID
                )
        )

        XCTAssertEqual(
            session
                .draft
                .activeProfileID,
            addedID
        )

        XCTAssertFalse(
            session
                .canUndo
        )

        XCTAssertTrue(
            session
                .canRedo
        )
    }

    private func makeSession(
        firstID:
            UUID,
        secondID:
            UUID
    ) -> HomeConfigurationEditorSession {
        let profiles = [
            RemappingProfile(
                id:
                    firstID,
                name:
                    "Profile 1"
            ),
            RemappingProfile(
                id:
                    secondID,
                name:
                    "Profile 2"
            )
        ]

        return HomeConfigurationEditorSession(
            snapshot:
                HomeConfigurationSnapshot(
                    profilesConfiguration:
                        RemappingProfilesConfiguration(
                            profiles:
                                profiles,
                            activeProfileID:
                                firstID
                        ),
                    launchBehavior:
                        .alwaysOff,
                    shortcutConfiguration:
                        .disabled
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
