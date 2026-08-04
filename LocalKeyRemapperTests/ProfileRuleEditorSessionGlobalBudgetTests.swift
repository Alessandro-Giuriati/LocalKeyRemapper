//
//  ProfileRuleEditorSessionGlobalBudgetTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/4/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileRuleEditorSessionGlobalBudgetTests:
    XCTestCase
{
    func testBudgetEvictsOldestCleanInactiveHistoryFirst() {
        let payloadPerSession =
            cleanHistoryPayloadSize()

        let registry =
            makeRegistry(
                maximumPayloadSize:
                    payloadPerSession * 2
            )

        let firstProfileID =
            UUID(
                uuidString:
                    "116F2B42-2F50-4894-B42A-676E0BED0FF4"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "71F4DB2E-7545-4F60-B410-7EB97B9FCD61"
            )!

        let displayedProfileID =
            UUID(
                uuidString:
                    "9CB59EDB-1AF5-449A-A352-3F5C53D15576"
            )!

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        firstProfileID
                )
        )

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        secondProfileID
                )
        )

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        displayedProfileID
                )
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions(
                excluding:
                    displayedProfileID
            )

        XCTAssertEqual(
            removedProfileIDs,
            Set(
                [
                    firstProfileID
                ]
            )
        )

        XCTAssertFalse(
            registry.containsSession(
                for:
                    firstProfileID
            )
        )

        XCTAssertTrue(
            registry.containsSession(
                for:
                    secondProfileID
            )
        )

        XCTAssertTrue(
            registry.containsSession(
                for:
                    displayedProfileID
            )
        )

        XCTAssertLessThanOrEqual(
            registry
                .totalEstimatedHistoryPayloadSize,
            registry
                .maximumRetainedEstimatedHistoryPayloadSizeLimit
        )
    }

    func testRecentAccessMovesCleanSessionToEndOfLRUOrder() {
        let payloadPerSession =
            cleanHistoryPayloadSize()

        let registry =
            makeRegistry(
                maximumPayloadSize:
                    payloadPerSession * 2
            )

        let firstProfileID =
            UUID(
                uuidString:
                    "DD7F0DD0-C517-40C4-A3E8-4DB6B5038025"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "1434C710-93CC-4F46-81A7-2648F74C5B7F"
            )!

        let displayedProfileID =
            UUID(
                uuidString:
                    "06E3E3B2-A8D2-489A-A0E1-A295FD4FC838"
            )!

        let firstSession =
            registry.session(
                for:
                    firstProfileID
            )

        makeCleanHistory(
            in:
                firstSession
        )

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        secondProfileID
                )
        )

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        displayedProfileID
                )
        )

        let recentlyAccessedFirstSession =
            registry.session(
                for:
                    firstProfileID
            )

        XCTAssertTrue(
            firstSession
                === recentlyAccessedFirstSession
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions(
                excluding:
                    displayedProfileID
            )

        XCTAssertEqual(
            removedProfileIDs,
            Set(
                [
                    secondProfileID
                ]
            )
        )

        XCTAssertTrue(
            registry.containsSession(
                for:
                    firstProfileID
            )
        )

        XCTAssertFalse(
            registry.containsSession(
                for:
                    secondProfileID
            )
        )
    }

    func testUnsavedSessionIsNeverEvictedEvenWhenBudgetIsZero() {
        let registry =
            makeRegistry(
                maximumPayloadSize:
                    0
            )

        let unsavedProfileID =
            UUID(
                uuidString:
                    "24DC0246-989C-48C2-9808-DA8CB599688A"
            )!

        let cleanProfileID =
            UUID(
                uuidString:
                    "84BBCAC4-B7A0-49F0-A71C-3F8359DD5B90"
            )!

        let unsavedSession =
            registry.session(
                for:
                    unsavedProfileID
            )

        unsavedSession.initialize(
            with:
                []
        )

        _ =
            unsavedSession
                .insertEmptyItem()

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        cleanProfileID
                )
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions()

        XCTAssertEqual(
            removedProfileIDs,
            Set(
                [
                    cleanProfileID
                ]
            )
        )

        XCTAssertTrue(
            registry.containsSession(
                for:
                    unsavedProfileID
            )
        )

        XCTAssertTrue(
            unsavedSession
                .hasUnsavedChanges
        )

        XCTAssertGreaterThan(
            registry
                .totalEstimatedHistoryPayloadSize,
            registry
                .maximumRetainedEstimatedHistoryPayloadSizeLimit
        )
    }

    func testDisplayedSessionIsNeverEvictedEvenWhenBudgetIsZero() {
        let registry =
            makeRegistry(
                maximumPayloadSize:
                    0
            )

        let displayedProfileID =
            UUID(
                uuidString:
                    "181D8043-264D-403C-A053-465819711484"
            )!

        let inactiveProfileID =
            UUID(
                uuidString:
                    "4D58819B-2A03-4F15-85E4-56AA46314344"
            )!

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        displayedProfileID
                )
        )

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        inactiveProfileID
                )
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions(
                excluding:
                    displayedProfileID
            )

        XCTAssertEqual(
            removedProfileIDs,
            Set(
                [
                    inactiveProfileID
                ]
            )
        )

        XCTAssertTrue(
            registry.containsSession(
                for:
                    displayedProfileID
            )
        )

        XCTAssertFalse(
            registry.containsSession(
                for:
                    inactiveProfileID
            )
        )
    }

    func testCleanupKeepsCleanHistoriesWhenTheyFitInsideBudget() {
        let payloadPerSession =
            cleanHistoryPayloadSize()

        let registry =
            makeRegistry(
                maximumPayloadSize:
                    payloadPerSession * 2
            )

        let firstProfileID =
            UUID(
                uuidString:
                    "22CB584E-AE73-46F9-B65D-6C450CB12927"
            )!

        let secondProfileID =
            UUID(
                uuidString:
                    "67054D2F-6446-4A38-B330-900303C960C4"
            )!

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        firstProfileID
                )
        )

        makeCleanHistory(
            in:
                registry.session(
                    for:
                        secondProfileID
                )
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions()

        XCTAssertTrue(
            removedProfileIDs
                .isEmpty
        )

        XCTAssertTrue(
            registry.containsSession(
                for:
                    firstProfileID
            )
        )

        XCTAssertTrue(
            registry.containsSession(
                for:
                    secondProfileID
            )
        )

        XCTAssertEqual(
            registry
                .totalEstimatedHistoryPayloadSize,
            payloadPerSession * 2
        )
    }

    private func makeRegistry(
        maximumPayloadSize:
            Int
    ) -> ProfileRuleEditorSessionRegistry {
        ProfileRuleEditorSessionRegistry(
            maximumRetainedEstimatedHistoryPayloadSize:
                maximumPayloadSize,
            sessionFactory: {
                RemappingRuleEditorSession(
                    history:
                        RuleEditorHistory(
                            maximumEntryCount:
                                100,
                            maximumEstimatedPayloadSize:
                                100_000
                        )
                )
            }
        )
    }

    private func cleanHistoryPayloadSize()
        -> Int
    {
        let session =
            RemappingRuleEditorSession(
                history:
                    RuleEditorHistory(
                        maximumEntryCount:
                            100,
                        maximumEstimatedPayloadSize:
                            100_000
                    )
            )

        makeCleanHistory(
            in:
                session
        )

        return session
            .estimatedHistoryPayloadSize
    }

    private func makeCleanHistory(
        in session:
            RemappingRuleEditorSession
    ) {
        session.initialize(
            with:
                []
        )

        _ =
            session
                .insertEmptyItem()

        session
            .restoreSavedRules()

        XCTAssertFalse(
            session
                .hasUnsavedChanges
        )

        XCTAssertGreaterThan(
            session
                .historyEntryCount,
            0
        )

        XCTAssertGreaterThan(
            session
                .estimatedHistoryPayloadSize,
            0
        )
    }
}
