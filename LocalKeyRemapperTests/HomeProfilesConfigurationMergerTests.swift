//
//  HomeProfilesConfigurationMergerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import Foundation
import XCTest
@testable import LocalKeyRemapper

final class HomeProfilesConfigurationMergerTests:
    XCTestCase
{
    func testMergeKeepsHomeMetadataAndLatestPersistedRules() throws {
        let firstID =
            UUID()
        let secondID =
            UUID()
        let newID =
            UUID()

        let firstCreatedAt =
            Date(
                timeIntervalSince1970:
                    10
            )
        let persistedRuleUpdate =
            Date(
                timeIntervalSince1970:
                    40
            )
        let draftRenameUpdate =
            Date(
                timeIntervalSince1970:
                    30
            )

        let latestPersistedRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.b,
                destinationKeyCode:
                    KeyCode.j
            )
        ]

        let persistedConfiguration =
            RemappingProfilesConfiguration(
                profiles: [
                    RemappingProfile(
                        id:
                            firstID,
                        name:
                            "Original",
                        createdAt:
                            firstCreatedAt,
                        updatedAt:
                            persistedRuleUpdate,
                        rules:
                            latestPersistedRules
                    ),
                    RemappingProfile(
                        id:
                            secondID,
                        name:
                            "Deleted in Home",
                        createdAt:
                            Date(
                                timeIntervalSince1970:
                                    20
                            ),
                        rules:
                            []
                    )
                ],
                activeProfileID:
                    firstID
            )

        let newProfileRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.n,
                destinationKeyCode:
                    KeyCode.r
            )
        ]

        let homeDraft =
            RemappingProfilesConfiguration(
                profiles: [
                    RemappingProfile(
                        id:
                            newID,
                        name:
                            "New Profile",
                        createdAt:
                            Date(
                                timeIntervalSince1970:
                                    50
                            ),
                        rules:
                            newProfileRules
                    ),
                    RemappingProfile(
                        id:
                            firstID,
                        name:
                            "Renamed",
                        createdAt:
                            Date(
                                timeIntervalSince1970:
                                    999
                            ),
                        updatedAt:
                            draftRenameUpdate,
                        rules: [
                            RemapRule(
                                sourceKeyCode:
                                    KeyCode.v,
                                destinationKeyCode:
                                    KeyCode.w
                            )
                        ]
                    )
                ],
                activeProfileID:
                    newID
            )

        let merged =
            HomeProfilesConfigurationMerger
                .merging(
                    homeDraft:
                        homeDraft,
                    persisted:
                        persistedConfiguration
                )

        XCTAssertEqual(
            merged.profiles.map(
                \.id
            ),
            [
                newID,
                firstID
            ]
        )

        XCTAssertEqual(
            merged.activeProfileID,
            newID
        )

        XCTAssertEqual(
            merged.profile(
                id:
                    newID
            )?
            .rules,
            newProfileRules
        )

        let mergedExistingProfile =
            try XCTUnwrap(
                merged.profile(
                    id:
                        firstID
                )
            )

        XCTAssertEqual(
            mergedExistingProfile.name,
            "Renamed"
        )

        XCTAssertEqual(
            mergedExistingProfile.createdAt,
            firstCreatedAt
        )

        XCTAssertEqual(
            mergedExistingProfile.updatedAt,
            persistedRuleUpdate
        )

        XCTAssertEqual(
            mergedExistingProfile.rules,
            latestPersistedRules
        )

        XCTAssertNil(
            merged.profile(
                id:
                    secondID
            )
        )
    }

    func testMergeUsesLaterHomeMetadataTimestamp() throws {
        let profileID =
            UUID()

        let persistedProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Profile",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            10
                    ),
                updatedAt:
                    Date(
                        timeIntervalSince1970:
                            20
                    ),
                rules:
                    []
            )

        let draftProfile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Renamed",
                createdAt:
                    persistedProfile.createdAt,
                updatedAt:
                    Date(
                        timeIntervalSince1970:
                            30
                    ),
                rules:
                    []
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

        XCTAssertEqual(
            try XCTUnwrap(
                merged.activeProfile
            )
            .updatedAt,
            draftProfile.updatedAt
        )
    }
}
