//
//  HomeProfilesShortcutColumnTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeProfilesShortcutColumnTests:
    XCTestCase
{
    func testProfilesTableContainsShortcutColumnInExpectedPosition() {
        let profile =
            RemappingProfile(
                name:
                    "Gaming"
            )

        let view =
            makeView(
                profiles: [
                    profile
                ],
                activeProfileID:
                    profile.id
            )

        XCTAssertEqual(
            view.columnIdentifiersForTesting,
            [
                "home.profiles.profile",
                "home.profiles.rules",
                "home.profiles.shortcut",
                "home.profiles.created",
                "home.profiles.actions"
            ]
        )
    }

    func testShortcutColumnUsesCompactPresentationTitles() {
        let defaultProfile =
            RemappingProfile(
                name:
                    "Default",
                shortcutConfigurationOverride:
                    nil
            )

        let offProfile =
            RemappingProfile(
                name:
                    "Off",
                shortcutConfigurationOverride:
                    .disabled
            )

        let toggleShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let toggleProfile =
            RemappingProfile(
                name:
                    "Toggle",
                shortcutConfigurationOverride:
                    .toggle(
                        toggleShortcut
                    )
            )

        let separateProfile =
            RemappingProfile(
                name:
                    "Separate",
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            makeShortcut(
                                keyCode:
                                    KeyCode.e
                            ),
                        disable:
                            makeShortcut(
                                keyCode:
                                    KeyCode.d
                            )
                    )
            )

        let view =
            makeView(
                profiles: [
                    defaultProfile,
                    offProfile,
                    toggleProfile,
                    separateProfile
                ],
                activeProfileID:
                    defaultProfile.id
            )

        // The Profiles presentation model sorts rows by name ascending
        // by default, independently from their persistent input order.
        XCTAssertEqual(
            shortcutTitles(
                in:
                    view
            ),
            [
                "Default",
                "Off",
                "Separate",
                KeyCombinationDisplayName
                    .name(
                        for:
                            toggleShortcut
                    )
            ]
        )
    }

    func testShortcutEditCallbackUsesStableProfileIdentity() {
        let profileID =
            UUID(
                uuidString:
                    "E5A2E820-F371-4668-A043-C83EC462F8EE"
            )!

        let profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming"
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    profile
                ],
                activeProfileID:
                    profileID
            )

        let session =
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

        let view =
            HomeProfilesSectionView(
                editorSession:
                    session,
                initialConfiguration:
                    configuration
            )

        var receivedProfileID:
            UUID?

        view.onEditShortcut = {
            profileID in

            receivedProfileID =
                profileID
        }

        view.editShortcutForVisibleProfileForTesting(
            at:
                0
        )

        XCTAssertEqual(
            receivedProfileID,
            profileID
        )
    }

    func testLoadingUpdatedDraftRefreshesShortcutSummary() {
        let profileID =
            UUID(
                uuidString:
                    "6ACB9C73-7CA6-48A3-BE53-F4C08E88462A"
            )!

        let originalProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    nil
            )

        let view =
            makeView(
                profiles: [
                    originalProfile
                ],
                activeProfileID:
                    profileID
            )

        XCTAssertEqual(
            view.shortcutTitleForVisibleProfileForTesting(
                at:
                    0
            ),
            "Default"
        )

        var updatedProfile =
            originalProfile

        updatedProfile.shortcutConfigurationOverride =
            .disabled

        view.load(
            configuration:
                RemappingProfilesConfiguration(
                    profiles: [
                        updatedProfile
                    ],
                    activeProfileID:
                        profileID
                )
        )

        XCTAssertEqual(
            view.shortcutTitleForVisibleProfileForTesting(
                at:
                    0
            ),
            "Off"
        )
    }

    private func makeView(
        profiles:
            [RemappingProfile],
        activeProfileID:
            UUID
    ) -> HomeProfilesSectionView {
        HomeProfilesSectionView(
            editorSession:
                nil,
            initialConfiguration:
                RemappingProfilesConfiguration(
                    profiles:
                        profiles,
                    activeProfileID:
                        activeProfileID
                )
        )
    }

    private func shortcutTitles(
        in view:
            HomeProfilesSectionView
    ) -> [String] {
        view.visibleProfileIDsForTesting
            .indices
            .compactMap {
                view.shortcutTitleForVisibleProfileForTesting(
                    at:
                        $0
                )
            }
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
}
