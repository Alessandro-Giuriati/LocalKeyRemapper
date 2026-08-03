//
//  HomeDestructiveUndoTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/3/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeDestructiveUndoTests:
    XCTestCase
{
    func testNextUndoPreviewReportsProfileRemovalWithoutMutatingSession() throws {
        let activeProfileID =
            fixedUUID(
                "7BAE9D30-C897-4693-A715-99B1DE1AB2E9"
            )

        let addedProfileID =
            fixedUUID(
                "E322F8A0-8C9F-4C6A-93D7-F35459C84E43"
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            makeProfile(
                                id:
                                    activeProfileID,
                                name:
                                    "Primary"
                            )
                        ],
                        activeProfileID:
                            activeProfileID
                    )
            )

        let addedProfile =
            try session.addProfile(
                id:
                    addedProfileID
            )

        session.markCurrentDraftAsSaved()

        let removedProfiles =
            session
                .profilesRemovedByNextUndo

        XCTAssertEqual(
            removedProfiles.map(
                \.id
            ),
            [
                addedProfileID
            ]
        )

        XCTAssertEqual(
            removedProfiles.first?.name,
            addedProfile.name
        )

        XCTAssertNotNil(
            session.draft.profile(
                id:
                    addedProfileID
            )
        )

        XCTAssertTrue(
            session.canUndo
        )

        XCTAssertFalse(
            session.canRedo
        )
    }

    func testNonDestructiveUndoProducesNoProfileRemovalPreview() {
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

        XCTAssertTrue(
            session
                .profilesRemovedByNextUndo
                .isEmpty
        )
    }

    func testRedoAfterSavedUndoDeletionRestoresLatestPersistedRules() throws {
        let activeProfileID =
            fixedUUID(
                "A6600675-0AB1-4867-9A75-1B6EB119D8F5"
            )

        let addedProfileID =
            fixedUUID(
                "2B620011-384A-4D85-BE07-115ECFF1F038"
            )

        let activeProfile =
            makeProfile(
                id:
                    activeProfileID,
                name:
                    "Primary"
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            activeProfile
                        ],
                        activeProfileID:
                            activeProfileID
                    )
            )

        let addedProfile =
            try session.addProfile(
                id:
                    addedProfileID
            )

        session.markCurrentDraftAsSaved()

        let latestRules =
            makeLatestRules()

        var persistedAddedProfile =
            addedProfile

        persistedAddedProfile.rules =
            latestRules

        persistedAddedProfile.updatedAt =
            Date(
                timeIntervalSince1970:
                    1_800_000_000
            )

        let persistedConfiguration =
            makeConfiguration(
                profiles: [
                    activeProfile,
                    persistedAddedProfile
                ],
                activeProfileID:
                    activeProfileID
            )

        session.undo()

        XCTAssertNil(
            session.draft.profile(
                id:
                    addedProfileID
            )
        )

        XCTAssertTrue(
            session.canRedo
        )

        try session
            .prepareHistoryForSavingCurrentDraft(
                using:
                    persistedConfiguration
            )

        let committedDeletionIDs =
            session.markCurrentDraftAsSaved()

        XCTAssertEqual(
            committedDeletionIDs,
            Set(
                [
                    addedProfileID
                ]
            )
        )

        XCTAssertTrue(
            session.canRedo
        )

        session.redo()

        let restoredProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        addedProfileID
                )
            )

        XCTAssertEqual(
            restoredProfile.rules,
            latestRules
        )

        XCTAssertEqual(
            restoredProfile.updatedAt,
            persistedAddedProfile.updatedAt
        )
    }

    func testUndoAfterSavedExplicitDeletionRestoresLatestPersistedRules() throws {
        let activeProfileID =
            fixedUUID(
                "5D304D2B-5A4B-45A3-98AA-C76DB710AB12"
            )

        let removedProfileID =
            fixedUUID(
                "13889FDD-95E0-40A9-8055-C5E17957E289"
            )

        let activeProfile =
            makeProfile(
                id:
                    activeProfileID,
                name:
                    "Primary"
            )

        let draftRemovedProfile =
            makeProfile(
                id:
                    removedProfileID,
                name:
                    "Gaming"
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            activeProfile,
                            draftRemovedProfile
                        ],
                        activeProfileID:
                            activeProfileID
                    )
            )

        let latestRules =
            makeLatestRules()

        var persistedRemovedProfile =
            draftRemovedProfile

        persistedRemovedProfile.rules =
            latestRules

        persistedRemovedProfile.updatedAt =
            Date(
                timeIntervalSince1970:
                    1_810_000_000
            )

        let persistedConfiguration =
            makeConfiguration(
                profiles: [
                    activeProfile,
                    persistedRemovedProfile
                ],
                activeProfileID:
                    activeProfileID
            )

        try session.removeProfile(
            id:
                removedProfileID
        )

        try session
            .prepareHistoryForSavingCurrentDraft(
                using:
                    persistedConfiguration
            )

        session.markCurrentDraftAsSaved()

        XCTAssertTrue(
            session.canUndo
        )

        session.undo()

        let restoredProfile =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        removedProfileID
                )
            )

        XCTAssertEqual(
            restoredProfile.rules,
            latestRules
        )

        XCTAssertEqual(
            restoredProfile.updatedAt,
            persistedRemovedProfile.updatedAt
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testSavedDeleteRestoreRedoCycleKeepsCompleteProfileRecoverable() throws {
        let activeProfileID =
            fixedUUID(
                "C6E1F271-CC74-4C47-81B1-52F77903CE51"
            )

        let removedProfileID =
            fixedUUID(
                "E927057A-92F3-4400-89F1-1798BA549F98"
            )

        let activeProfile =
            makeProfile(
                id:
                    activeProfileID,
                name:
                    "Primary"
            )

        let latestRules =
            makeLatestRules()

        let removedProfile =
            makeProfile(
                id:
                    removedProfileID,
                name:
                    "Gaming",
                rules:
                    latestRules
            )

        let persistedConfiguration =
            makeConfiguration(
                profiles: [
                    activeProfile,
                    removedProfile
                ],
                activeProfileID:
                    activeProfileID
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            activeProfile,
                            removedProfile
                        ],
                        activeProfileID:
                            activeProfileID
                    )
            )

        try session.removeProfile(
            id:
                removedProfileID
        )

        try session
            .prepareHistoryForSavingCurrentDraft(
                using:
                    persistedConfiguration
            )

        session.markCurrentDraftAsSaved()
        session.undo()

        XCTAssertEqual(
            session.draft.profile(
                id:
                    removedProfileID
            )?.rules,
            latestRules
        )

        session.markCurrentDraftAsSaved()
        session.redo()

        XCTAssertNil(
            session.draft.profile(
                id:
                    removedProfileID
            )
        )

        try session
            .prepareHistoryForSavingCurrentDraft(
                using:
                    persistedConfiguration
            )

        session.markCurrentDraftAsSaved()
        session.undo()

        XCTAssertEqual(
            session.draft.profile(
                id:
                    removedProfileID
            )?.rules,
            latestRules
        )
    }

    func testCommittedProfileDeletionPreservesUnrelatedHomeHistory() throws {
        let activeProfileID =
            fixedUUID(
                "8E71CC14-11D0-43E9-8822-FBB5AA2BC743"
            )

        let removedProfileID =
            fixedUUID(
                "F0133A0A-C76F-4EB2-9062-E49F36414E4F"
            )

        let activeProfile =
            makeProfile(
                id:
                    activeProfileID,
                name:
                    "Primary"
            )

        let removedProfile =
            makeProfile(
                id:
                    removedProfileID,
                name:
                    "Gaming",
                rules:
                    makeLatestRules()
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            activeProfile,
                            removedProfile
                        ],
                        activeProfileID:
                            activeProfileID,
                        launchBehavior:
                            .alwaysOff
                    )
            )

        session.setLaunchBehavior(
            .alwaysOn
        )

        try session.removeProfile(
            id:
                removedProfileID
        )

        try session
            .prepareHistoryForSavingCurrentDraft(
                using:
                    makeConfiguration(
                        profiles: [
                            activeProfile,
                            removedProfile
                        ],
                        activeProfileID:
                            activeProfileID
                    )
            )

        session.markCurrentDraftAsSaved()

        session.undo()

        XCTAssertNotNil(
            session.draft.profile(
                id:
                    removedProfileID
            )
        )

        session.undo()

        XCTAssertEqual(
            session.draft.launchBehavior,
            .alwaysOff
        )
    }

    func testSavePreparationFailsAtomicallyWhenRefreshedRulesExceedMemoryLimit() throws {
        let activeProfileID =
            fixedUUID(
                "605D59F3-F213-40E9-9750-493D0599D166"
            )

        let removedProfileID =
            fixedUUID(
                "2401F445-C132-4FDD-9031-C8B9ED346A76"
            )

        let activeProfile =
            makeProfile(
                id:
                    activeProfileID,
                name:
                    "Primary"
            )

        let removedProfile =
            makeProfile(
                id:
                    removedProfileID,
                name:
                    "Large"
            )

        let history =
            HomeConfigurationHistory(
                maximumEntryCount:
                    100,
                maximumEstimatedPayloadSize:
                    500
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    makeSnapshot(
                        profiles: [
                            activeProfile,
                            removedProfile
                        ],
                        activeProfileID:
                            activeProfileID
                    ),
                history:
                    history
            )

        try session.removeProfile(
            id:
                removedProfileID
        )

        let payloadBeforePreparation =
            session
                .estimatedHistoryPayloadSize

        var persistedRemovedProfile =
            removedProfile

        persistedRemovedProfile.rules =
            Array(
                repeating:
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    ),
                count:
                    10
            )

        XCTAssertThrowsError(
            try session
                .prepareHistoryForSavingCurrentDraft(
                    using:
                        makeConfiguration(
                            profiles: [
                                activeProfile,
                                persistedRemovedProfile
                            ],
                            activeProfileID:
                                activeProfileID
                        )
                )
        ) {
            error in

            guard
                case HomeConfigurationHistoryPreparationError
                    .payloadLimitExceeded(
                        let required,
                        let maximum
                    ) = error
            else {
                XCTFail(
                    "Unexpected error: \(error)"
                )
                return
            }

            XCTAssertGreaterThan(
                required,
                maximum
            )

            XCTAssertEqual(
                maximum,
                500
            )
        }

        XCTAssertEqual(
            session.estimatedHistoryPayloadSize,
            payloadBeforePreparation
        )

        XCTAssertTrue(
            session.canUndo
        )

        XCTAssertNil(
            session.draft.profile(
                id:
                    removedProfileID
            )
        )
    }

    func testDestructiveRemovalIsRejectedWhenItsRecoveryEntryCannotFit() {
        let activeProfileID =
            fixedUUID(
                "3A6911AF-E5B1-420F-8DDA-1B5C736D4D01"
            )

        let removedProfileID =
            fixedUUID(
                "44A49DD3-BE8C-4119-A2EA-F0CD37512900"
            )

        let snapshot =
            makeSnapshot(
                profiles: [
                    makeProfile(
                        id:
                            activeProfileID,
                        name:
                            "Primary"
                    ),
                    makeProfile(
                        id:
                            removedProfileID,
                        name:
                            "Gaming"
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let session =
            HomeConfigurationEditorSession(
                snapshot:
                    snapshot,
                history:
                    HomeConfigurationHistory(
                        maximumEntryCount:
                            100,
                        maximumEstimatedPayloadSize:
                            1
                    )
            )

        XCTAssertThrowsError(
            try session.removeProfile(
                id:
                    removedProfileID
            )
        ) {
            error in

            guard
                case HomeConfigurationEditorSessionError
                    .undoHistoryCapacityExceeded(
                        let required,
                        let maximum
                    ) = error
            else {
                XCTFail(
                    "Unexpected error: \(error)"
                )
                return
            }

            XCTAssertGreaterThan(
                required,
                maximum
            )

            XCTAssertEqual(
                maximum,
                1
            )
        }

        XCTAssertEqual(
            session.draft,
            snapshot
        )

        XCTAssertFalse(
            session.canUndo
        )
    }

    private func makeLatestRules()
        -> [RemapRule]
    {
        [
            RemapRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w
            ),
            RemapRule(
                sourceKeyCode:
                    KeyCode.w,
                destinationKeyCode:
                    KeyCode.v
            )
        ]
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
        let resolvedConfiguration =
            makeConfiguration(
                profiles:
                    profiles,
                activeProfileID:
                    activeProfileID
            )

        return HomeConfigurationSnapshot(
            profilesConfiguration:
                resolvedConfiguration,
            launchBehavior:
                launchBehavior,
            shortcutConfiguration:
                shortcutConfiguration
        )
    }

    private func makeConfiguration(
        profiles:
            [RemappingProfile]? = nil,
        activeProfileID:
            UUID? = nil
    ) -> RemappingProfilesConfiguration {
        let fallbackID =
            fixedUUID(
                "DC221465-4036-4DC1-B2BF-98F4EE4E7D1A"
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

        return RemappingProfilesConfiguration(
            profiles:
                resolvedProfiles,
            activeProfileID:
                resolvedActiveProfileID
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
