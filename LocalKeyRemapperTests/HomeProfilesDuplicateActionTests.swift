//
//  HomeProfilesDuplicateActionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeProfilesDuplicateActionTests:
    XCTestCase
{
    func testDuplicateActionCopiesCompleteProfileAndSupportsUndoRedo()
        throws
    {
        let sourceProfileID =
            fixedUUID(
                "DCC20906-8436-42B4-B7A9-75C42DB8B20A"
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
                    sourceProfile
                ],
                activeProfileID:
                    sourceProfileID
            )

        let session =
            makeSession(
                configuration:
                    configuration
            )

        let view =
            HomeProfilesSectionView(
                editorSession:
                    session,
                initialConfiguration:
                    configuration
            )

        session.onChange = {
            view.load(
                configuration:
                    session
                        .draft
                        .profilesConfiguration
            )
        }

        view.duplicateVisibleProfileForTesting(
            at:
                0
        )

        XCTAssertEqual(
            session.draft.profiles.count,
            2
        )

        XCTAssertEqual(
            session.draft.activeProfileID,
            sourceProfileID
        )

        XCTAssertEqual(
            session.historyEntryCount,
            1
        )

        let duplicate =
            try XCTUnwrap(
                session
                    .draft
                    .profiles
                    .first(
                        where: {
                            $0.id
                                != sourceProfileID
                        }
                    )
            )

        XCTAssertEqual(
            duplicate.name,
            "Gaming Copy"
        )

        XCTAssertNotEqual(
            duplicate.id,
            sourceProfileID
        )

        XCTAssertEqual(
            duplicate.rules,
            sourceProfile.rules
        )

        XCTAssertEqual(
            duplicate
                .shortcutConfigurationOverride,
            sourceProfile
                .shortcutConfigurationOverride
        )

        XCTAssertEqual(
            duplicate.shortcutMemory,
            sourceProfile.shortcutMemory
        )

        XCTAssertEqual(
            view.selectedProfileIDForTesting,
            duplicate.id
        )

        XCTAssertTrue(
            view.visibleProfileIDsForTesting
                .contains(
                    duplicate.id
                )
        )

        session.undo()

        XCTAssertEqual(
            session.draft.profiles.count,
            1
        )

        XCTAssertNil(
            session.draft.profile(
                id:
                    duplicate.id
            )
        )

        session.redo()

        let restoredDuplicate =
            try XCTUnwrap(
                session.draft.profile(
                    id:
                        duplicate.id
                )
            )

        XCTAssertEqual(
            restoredDuplicate.rules,
            sourceProfile.rules
        )

        XCTAssertEqual(
            restoredDuplicate.shortcutMemory,
            sourceProfile.shortcutMemory
        )

        XCTAssertEqual(
            session.draft.activeProfileID,
            sourceProfileID
        )
    }

    func testDuplicateActionUsesNextCopyNameAndReportsStatus()
        throws
    {
        let sourceProfile =
            RemappingProfile(
                name:
                    "Gaming"
            )

        let existingCopy =
            RemappingProfile(
                name:
                    "Gaming Copy"
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    sourceProfile,
                    existingCopy
                ],
                activeProfileID:
                    sourceProfile.id
            )

        let session =
            makeSession(
                configuration:
                    configuration
            )

        let view =
            HomeProfilesSectionView(
                editorSession:
                    session,
                initialConfiguration:
                    configuration
            )

        session.onChange = {
            view.load(
                configuration:
                    session
                        .draft
                        .profilesConfiguration
            )
        }

        var statusMessage:
            String?

        var statusIsError:
            Bool?

        view.onStatusChange = {
            message,
            isError in

            statusMessage =
                message

            statusIsError =
                isError
        }

        let sourceVisibleIndex =
            try XCTUnwrap(
                view
                    .visibleProfileIDsForTesting
                    .firstIndex(
                        of:
                            sourceProfile.id
                    )
            )

        view.duplicateVisibleProfileForTesting(
            at:
                sourceVisibleIndex
        )

        let duplicate =
            try XCTUnwrap(
                session
                    .draft
                    .profiles
                    .first(
                        where: {
                            $0.name
                                == "Gaming Copy 2"
                        }
                    )
            )

        XCTAssertEqual(
            view.selectedProfileIDForTesting,
            duplicate.id
        )

        XCTAssertEqual(
            statusMessage,
            "“Gaming Copy 2” was duplicated from “Gaming” in the Home draft."
        )

        XCTAssertEqual(
            statusIsError,
            false
        )

        XCTAssertEqual(
            session.draft.activeProfileID,
            sourceProfile.id
        )
    }

    private func makeSession(
        configuration:
            RemappingProfilesConfiguration
    ) -> HomeConfigurationEditorSession {
        HomeConfigurationEditorSession(
            snapshot:
                HomeConfigurationSnapshot(
                    profilesConfiguration:
                        configuration,
                    launchBehavior:
                        .alwaysOff,
                    shortcutConfiguration:
                        .disabled
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
