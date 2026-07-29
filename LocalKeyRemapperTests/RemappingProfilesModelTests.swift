//
//  RemappingProfilesModelTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import XCTest

@testable import LocalKeyRemapper

@MainActor
final class RemappingProfilesModelTests:
    XCTestCase
{
    func testInitialConfigurationCreatesOneActiveProfileWithDefaultRule() {
        let profileID =
            UUID(
                uuidString:
                    "6C927150-CF5F-4C82-95C9-05BED29658B2"
            )!

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let configuration =
            RemappingProfilesConfiguration.initial(
                profileID:
                    profileID,
                timestamp:
                    timestamp
            )

        XCTAssertEqual(
            configuration.profiles.count,
            1
        )

        XCTAssertEqual(
            configuration.activeProfileID,
            profileID
        )

        guard
            let activeProfile =
                configuration.activeProfile
        else {
            XCTFail(
                "The initial active profile should exist."
            )

            return
        }

        XCTAssertEqual(
            activeProfile.id,
            profileID
        )

        XCTAssertEqual(
            activeProfile.name,
            "Profile 1"
        )

        XCTAssertEqual(
            activeProfile.createdAt,
            timestamp
        )

        XCTAssertEqual(
            activeProfile.updatedAt,
            timestamp
        )

        XCTAssertEqual(
            activeProfile.rules.count,
            1
        )

        XCTAssertEqual(
            activeProfile.rules[0].source.keyCode,
            KeyCode.v
        )

        XCTAssertEqual(
            activeProfile.rules[0].destination.keyCode,
            KeyCode.w
        )
    }

    func testProfileLookupUsesStableIdentity() {
        let firstProfileID =
            UUID(
                uuidString:
                    "43E71861-B39F-43B5-A3EE-F12B5D6B209E"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "F6B471AA-FC6D-4184-B3D6-C7E34E500F73"
            )!

        let timestamp =
            Date(
                timeIntervalSince1970:
                    1_700_000_000
            )

        let firstProfile =
            RemappingProfile(
                id:
                    firstProfileID,
                name:
                    "Gaming",
                createdAt:
                    timestamp
            )

        let secondProfile =
            RemappingProfile(
                id:
                    secondProfileID,
                name:
                    "Work",
                createdAt:
                    timestamp
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    firstProfile,
                    secondProfile
                ],
                activeProfileID:
                    secondProfileID
            )

        XCTAssertEqual(
            configuration.activeProfile,
            secondProfile
        )

        XCTAssertEqual(
            configuration.profile(
                id:
                    firstProfileID
            ),
            firstProfile
        )
    }

    func testRenamingProfileDoesNotChangeItsIdentity() {
        let profileID =
            UUID(
                uuidString:
                    "48E050F8-5BB5-4B86-96BB-98C79CDF411D"
            )!

        var profile =
            RemappingProfile(
                id:
                    profileID,
                name:
                    "Profile 1"
            )

        profile.name =
            "Gaming"

        XCTAssertEqual(
            profile.id,
            profileID
        )

        XCTAssertEqual(
            profile.name,
            "Gaming"
        )
    }

    func testInitialConfigurationAcceptsInjectedRules() {
        let configuration =
            RemappingProfilesConfiguration.initial(
                defaultRules: []
            )

        XCTAssertEqual(
            configuration.activeProfile?.rules,
            []
        )
    }
}
