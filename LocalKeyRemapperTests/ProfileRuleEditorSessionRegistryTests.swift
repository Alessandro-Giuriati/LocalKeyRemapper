//
//  ProfileRuleEditorSessionRegistryTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/29/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileRuleEditorSessionRegistryTests:
    XCTestCase
{
    func testRepeatedRequestsForSameProfileReturnSameSession() {
        let profileID =
            UUID(
                uuidString:
                    "7D81D643-D345-448A-8F8E-4B69B9773990"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let firstSession =
            registry.session(
                for:
                    profileID
            )

        let secondSession =
            registry.session(
                for:
                    profileID
            )

        XCTAssertTrue(
            firstSession === secondSession
        )
    }

    func testDifferentProfilesReceiveIndependentSessions() {
        let firstProfileID =
            UUID(
                uuidString:
                    "FB3793CA-65EA-4541-A90C-CC505D67281B"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "38B67476-3310-4D88-8990-B00440392EEC"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let firstSession =
            registry.session(
                for:
                    firstProfileID
            )

        let secondSession =
            registry.session(
                for:
                    secondProfileID
            )

        XCTAssertFalse(
            firstSession === secondSession
        )
    }

    func testSessionIsCreatedOnlyWhenRequested() {
        var creationCount = 0

        let registry =
            ProfileRuleEditorSessionRegistry(
                sessionFactory: {
                    creationCount += 1

                    return RemappingRuleEditorSession()
                }
            )

        XCTAssertEqual(
            creationCount,
            0
        )

        _ =
            registry.session(
                for:
                    UUID(
                        uuidString:
                            "50670914-64F6-40D1-AE38-947BDB86D95C"
                    )!
            )

        XCTAssertEqual(
            creationCount,
            1
        )
    }

    func testRepeatedRequestDoesNotCreateSecondSession() {
        let profileID =
            UUID(
                uuidString:
                    "E912A812-D26E-4E0C-BE59-6AC40DC2391D"
            )!

        var creationCount = 0

        let registry =
            ProfileRuleEditorSessionRegistry(
                sessionFactory: {
                    creationCount += 1

                    return RemappingRuleEditorSession()
                }
            )

        _ =
            registry.session(
                for:
                    profileID
            )

        _ =
            registry.session(
                for:
                    profileID
            )

        XCTAssertEqual(
            creationCount,
            1
        )
    }

    func testRemovingSessionCausesNextRequestToCreateNewSession() {
        let profileID =
            UUID(
                uuidString:
                    "2CDA7FBF-D681-49CD-96B6-8CE64BD018DA"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let originalSession =
            registry.session(
                for:
                    profileID
            )

        registry.removeSession(
            for:
                profileID
        )

        let replacementSession =
            registry.session(
                for:
                    profileID
            )

        XCTAssertFalse(
            originalSession === replacementSession
        )
    }

    func testRemovingOneProfileDoesNotRemoveAnotherProfileSession() {
        let firstProfileID =
            UUID(
                uuidString:
                    "7EED7892-4682-44DC-8ECC-A8B86B10FDDD"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "8E0F8E66-E797-47CA-9888-50FDC748AD7C"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let firstSession =
            registry.session(
                for:
                    firstProfileID
            )

        let secondSession =
            registry.session(
                for:
                    secondProfileID
            )

        registry.removeSession(
            for:
                firstProfileID
        )

        let recreatedFirstSession =
            registry.session(
                for:
                    firstProfileID
            )

        let retainedSecondSession =
            registry.session(
                for:
                    secondProfileID
            )

        XCTAssertFalse(
            firstSession === recreatedFirstSession
        )

        XCTAssertTrue(
            secondSession === retainedSecondSession
        )
    }

    func testRemovingAllSessionsReleasesEveryStoredSession() {
        let firstProfileID =
            UUID(
                uuidString:
                    "B91A2D6A-B4F9-4677-B887-C29B6E46AC9A"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "E71151AE-FE36-4E47-B4E3-D2A59D72571D"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let originalFirstSession =
            registry.session(
                for:
                    firstProfileID
            )

        let originalSecondSession =
            registry.session(
                for:
                    secondProfileID
            )

        registry.removeAllSessions()

        let replacementFirstSession =
            registry.session(
                for:
                    firstProfileID
            )

        let replacementSecondSession =
            registry.session(
                for:
                    secondProfileID
            )

        XCTAssertFalse(
            originalFirstSession === replacementFirstSession
        )

        XCTAssertFalse(
            originalSecondSession === replacementSecondSession
        )
    }
}
