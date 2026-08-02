//
//  HomeProfilesSectionViewTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import Foundation
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class HomeProfilesSectionViewTests:
    XCTestCase
{
    func testTableShowsAtMostFourRowsBeforeScrolling() {
        let oneProfileView =
            makeView(
                profileCount:
                    1
            )
        XCTAssertEqual(
            oneProfileView
                .visibleRowCapacityForTesting,
            1
        )
        XCTAssertFalse(
            oneProfileView
                .usesVerticalScrollingForTesting
        )

        let fourProfileView =
            makeView(
                profileCount:
                    4
            )
        XCTAssertEqual(
            fourProfileView
                .visibleRowCapacityForTesting,
            4
        )
        XCTAssertFalse(
            fourProfileView
                .usesVerticalScrollingForTesting
        )

        let fiveProfileView =
            makeView(
                profileCount:
                    5
            )
        XCTAssertEqual(
            fiveProfileView
                .visibleRowCapacityForTesting,
            4
        )
        XCTAssertTrue(
            fiveProfileView
                .usesVerticalScrollingForTesting
        )
    }

    func testSearchAndSortingDoNotCreateHomeHistory() {
        let profiles =
            makeProfiles(
                count:
                    4
            )
        let configuration =
            RemappingProfilesConfiguration(
                profiles:
                    profiles,
                activeProfileID:
                    profiles[0].id
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

        view.setSearchTextForTesting(
            "Profile 2"
        )
        view.toggleSortForTesting(
            .creationDate
        )
        view.toggleSortForTesting(
            .creationDate
        )

        XCTAssertEqual(
            session.historyEntryCount,
            0
        )
        XCTAssertFalse(
            session.hasUnsavedChanges
        )
        XCTAssertEqual(
            session.draft.profiles,
            profiles
        )
    }

    func testFilteredOpenActionUsesProfileUUID() {
        let firstID =
            fixedUUID(
                "D7D129E6-37D6-4C90-9EA0-329A5E89E972"
            )
        let targetID =
            fixedUUID(
                "295A0936-0ADF-4E5F-BC3A-E0BB8F32AD40"
            )
        let profiles = [
            RemappingProfile(
                id:
                    firstID,
                name:
                    "Gaming"
            ),
            RemappingProfile(
                id:
                    targetID,
                name:
                    "Coding"
            )
        ]
        let configuration =
            RemappingProfilesConfiguration(
                profiles:
                    profiles,
                activeProfileID:
                    firstID
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

        var openedProfileID:
            UUID?
        view.onOpenProfile = {
            profileID in

            openedProfileID =
                profileID
        }

        view.setSearchTextForTesting(
            "coding"
        )
        view.openVisibleProfileForTesting(
            at:
                0
        )

        XCTAssertEqual(
            openedProfileID,
            targetID
        )
    }

    private func makeView(
        profileCount:
            Int
    ) -> HomeProfilesSectionView {
        let profiles =
            makeProfiles(
                count:
                    profileCount
            )
        let configuration =
            RemappingProfilesConfiguration(
                profiles:
                    profiles,
                activeProfileID:
                    profiles[0].id
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

        return HomeProfilesSectionView(
            editorSession:
                session,
            initialConfiguration:
                configuration
        )
    }

    private func makeProfiles(
        count:
            Int
    ) -> [RemappingProfile] {
        (1...count).map {
            index in

            let timestamp =
                Date(
                    timeIntervalSince1970:
                        TimeInterval(
                            index
                        )
                )

            return RemappingProfile(
                name:
                    "Profile \(index)",
                createdAt:
                    timestamp
            )
        }
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
