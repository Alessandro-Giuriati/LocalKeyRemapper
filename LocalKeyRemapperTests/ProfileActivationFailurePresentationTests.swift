//
//  ProfileActivationFailurePresentationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/5/26.
//

import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class ProfileActivationFailurePresentationTests:
    XCTestCase
{
    func testDefaultToggleConflictNamesDefaultSourceAndToggleAction() {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let failure =
            makeFailure(
                profile:
                    RemappingProfile(
                        name:
                            "Game"
                    ),
                action:
                    .toggle,
                shortcut:
                    shortcut
            )

        XCTAssertEqual(
            failure.shortcutSource,
            .defaultGlobal
        )

        XCTAssertEqual(
            ProfileActivationFailurePresentation
                .message(
                    for:
                        failure
                ),
            "“Game” wasn’t activated because one of its rules conflicts with the Default Global Shortcut “Toggle Remapping” (\(displayName(for: shortcut))). Change the default shortcut in Home or edit the conflicting rule in “Game”. The previous profile remains active."
        )
    }

    func testDefaultSeparateConflictsIdentifyEnableAndDisableActions() {
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
                    "Game"
            )

        let enableFailure =
            makeFailure(
                profile:
                    profile,
                action:
                    .enable,
                shortcut:
                    enableShortcut
            )

        let disableFailure =
            makeFailure(
                profile:
                    profile,
                action:
                    .disable,
                shortcut:
                    disableShortcut
            )

        XCTAssertEqual(
            ProfileActivationFailurePresentation
                .message(
                    for:
                        enableFailure
                ),
            "“Game” wasn’t activated because one of its rules conflicts with the Default Global Shortcut “Enable Remapping” (\(displayName(for: enableShortcut))). Change the default shortcut in Home or edit the conflicting rule in “Game”. The previous profile remains active."
        )

        XCTAssertEqual(
            ProfileActivationFailurePresentation
                .message(
                    for:
                        disableFailure
                ),
            "“Game” wasn’t activated because one of its rules conflicts with the Default Global Shortcut “Disable Remapping” (\(displayName(for: disableShortcut))). Change the default shortcut in Home or edit the conflicting rule in “Game”. The previous profile remains active."
        )
    }

    func testProfileToggleConflictNamesProfileSpecificSource() {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Game",
                shortcutConfigurationOverride:
                    .toggle(
                        shortcut
                    )
            )

        let failure =
            makeFailure(
                profile:
                    profile,
                action:
                    .toggle,
                shortcut:
                    shortcut
            )

        XCTAssertEqual(
            failure.shortcutSource,
            .profileSpecific
        )

        XCTAssertEqual(
            ProfileActivationFailurePresentation
                .message(
                    for:
                        failure
                ),
            "“Game” wasn’t activated because one of its rules conflicts with its profile shortcut “Toggle Remapping” (\(displayName(for: shortcut))). Change the shortcut configured for “Game” or edit the conflicting rule. The previous profile remains active."
        )
    }

    func testProfileSeparateConflictsIdentifyEnableAndDisableActions() {
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
                    "Game",
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            enableShortcut,
                        disable:
                            disableShortcut
                    )
            )

        let enableFailure =
            makeFailure(
                profile:
                    profile,
                action:
                    .enable,
                shortcut:
                    enableShortcut
            )

        let disableFailure =
            makeFailure(
                profile:
                    profile,
                action:
                    .disable,
                shortcut:
                    disableShortcut
            )

        XCTAssertEqual(
            ProfileActivationFailurePresentation
                .message(
                    for:
                        enableFailure
                ),
            "“Game” wasn’t activated because one of its rules conflicts with its profile shortcut “Enable Remapping” (\(displayName(for: enableShortcut))). Change the shortcut configured for “Game” or edit the conflicting rule. The previous profile remains active."
        )

        XCTAssertEqual(
            ProfileActivationFailurePresentation
                .message(
                    for:
                        disableFailure
                ),
            "“Game” wasn’t activated because one of its rules conflicts with its profile shortcut “Disable Remapping” (\(displayName(for: disableShortcut))). Change the shortcut configured for “Game” or edit the conflicting rule. The previous profile remains active."
        )
    }

    func testHomeCanUseAnUnsavedDisplayedProfileName() {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let failure =
            makeFailure(
                profile:
                    RemappingProfile(
                        name:
                            "Persisted Name"
                    ),
                action:
                    .toggle,
                shortcut:
                    shortcut
            )

        XCTAssertEqual(
            ProfileActivationFailurePresentation
                .message(
                    for:
                        failure,
                    displayedProfileName:
                        "Unsaved Name"
                ),
            "“Unsaved Name” wasn’t activated because one of its rules conflicts with the Default Global Shortcut “Toggle Remapping” (\(displayName(for: shortcut))). Change the default shortcut in Home or edit the conflicting rule in “Unsaved Name”. The previous profile remains active."
        )
    }

    private func makeFailure(
        profile:
            RemappingProfile,
        action:
            GlobalShortcutAction,
        shortcut:
            KeyCombination
    ) -> ProfileActivationShortcutConflict {
        ProfileActivationShortcutConflict(
            profile:
                profile,
            conflict:
                RemappingShortcutRuleConflict(
                    ruleIndex:
                        0,
                    action:
                        action,
                    shortcut:
                        shortcut
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

    private func displayName(
        for shortcut:
            KeyCombination
    ) -> String {
        KeyCombinationDisplayName
            .name(
                for:
                    shortcut
            )
    }
}
