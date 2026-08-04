//
//  ProfileRuleEditorSessionRetentionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/3/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileRuleEditorSessionRetentionTests:
    XCTestCase
{
    func testCleanupReleasesCleanInactiveSessionWithoutHistory() {
        let cleanProfileID =
            UUID(
                uuidString:
                    "497CA0B4-B522-408B-A492-851CB10312E7"
            )!

        let displayedProfileID =
            UUID(
                uuidString:
                    "EA04260F-5DB3-407A-AE06-F15EAB8E8F43"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let originalSession =
            registry.session(
                for:
                    cleanProfileID
            )

        originalSession.initialize(
            with:
                []
        )

        XCTAssertFalse(
            originalSession.hasUnsavedChanges
        )

        XCTAssertEqual(
            originalSession.historyEntryCount,
            0
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
                    cleanProfileID
                ]
            )
        )

        let replacementSession =
            registry.session(
                for:
                    cleanProfileID
            )

        XCTAssertFalse(
            originalSession
                === replacementSession
        )
    }

    func testCleanupPreservesCurrentlyDisplayedSession() {
        let displayedProfileID =
            UUID(
                uuidString:
                    "3BB70C8D-6DEE-4DDA-8594-D68E289A04F9"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let originalSession =
            registry.session(
                for:
                    displayedProfileID
            )

        originalSession.initialize(
            with:
                []
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions(
                excluding:
                    displayedProfileID
            )

        XCTAssertTrue(
            removedProfileIDs.isEmpty
        )

        let retainedSession =
            registry.session(
                for:
                    displayedProfileID
            )

        XCTAssertTrue(
            originalSession
                === retainedSession
        )
    }

    func testCleanupPreservesSessionWithUnsavedChanges() {
        let profileID =
            UUID(
                uuidString:
                    "F42D8B55-3622-412A-BBC4-84C29725453B"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let originalSession =
            registry.session(
                for:
                    profileID
            )

        originalSession.initialize(
            with:
                []
        )

        _ =
            originalSession
                .insertEmptyItem()

        XCTAssertTrue(
            originalSession.hasUnsavedChanges
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions()

        XCTAssertFalse(
            removedProfileIDs.contains(
                profileID
            )
        )

        let retainedSession =
            registry.session(
                for:
                    profileID
            )

        XCTAssertTrue(
            originalSession
                === retainedSession
        )
    }

    func testCleanupPreservesCleanSessionWithUndoRedoHistory() {
        let profileID =
            UUID(
                uuidString:
                    "1B722516-F215-4277-8655-E9D184C67A46"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let originalSession =
            registry.session(
                for:
                    profileID
            )

        originalSession.initialize(
            with:
                []
        )

        _ =
            originalSession
                .insertEmptyItem()

        originalSession
            .restoreSavedRules()

        XCTAssertFalse(
            originalSession.hasUnsavedChanges
        )

        XCTAssertGreaterThan(
            originalSession.historyEntryCount,
            0
        )

        let removedProfileIDs =
            registry.removeDiscardableSessions()

        XCTAssertFalse(
            removedProfileIDs.contains(
                profileID
            )
        )

        let retainedSession =
            registry.session(
                for:
                    profileID
            )

        XCTAssertTrue(
            originalSession
                === retainedSession
        )
    }

    func testUnsavedProfileIDsInspectOnlyRetainedUnsavedSessions() {
        let cleanProfileID =
            UUID(
                uuidString:
                    "F49A3787-78C8-4827-A298-599B982FD745"
            )!

        let unsavedProfileID =
            UUID(
                uuidString:
                    "2CF7771F-E80D-476A-9E5B-C5EA12BB00E4"
            )!

        let uninitializedProfileID =
            UUID(
                uuidString:
                    "36D04F64-1909-4FF3-A8FE-F0C0CF1125DB"
            )!

        let registry =
            ProfileRuleEditorSessionRegistry()

        let cleanSession =
            registry.session(
                for:
                    cleanProfileID
            )

        cleanSession.initialize(
            with:
                []
        )

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

        _ =
            registry.session(
                for:
                    uninitializedProfileID
            )

        XCTAssertEqual(
            registry.profileIDsWithUnsavedChanges,
            Set(
                [
                    unsavedProfileID
                ]
            )
        )
    }

    func testCoordinatorReleasesCleanPreviousSessionAfterProfileSwitch()
        throws
    {
        let coordinator =
            AppCoordinator()

        coordinator.start()

        defer {
            cleanUp(
                coordinator
            )
        }

        guard
            let homeSession =
                reflectedHomeConfigurationEditorSession(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "Starting the coordinator did not create a Home editor session."
            )
            return
        }

        let firstProfileID =
            homeSession
                .draft
                .activeProfileID

        let secondProfile =
            try homeSession.addProfile(
                id:
                    UUID(
                        uuidString:
                            "BD9194DE-FB56-4C47-8320-C07836A3C473"
                    )!,
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_900_000_000
                    )
            )

        coordinator.showRemappingRulesWindow(
            for:
                firstProfileID
        )

        guard
            let firstController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                ),
            let firstSession =
                reflectedRuleEditorSession(
                    from:
                        firstController
                )
        else {
            XCTFail(
                "The first profile did not receive a Rules editor session."
            )
            return
        }

        XCTAssertFalse(
            firstSession.hasUnsavedChanges
        )

        XCTAssertEqual(
            firstSession.historyEntryCount,
            0
        )

        coordinator.showRemappingRulesWindow(
            for:
                secondProfile.id
        )

        guard
            let secondController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                ),
            let secondSession =
                reflectedRuleEditorSession(
                    from:
                        secondController
                ),
            let registry =
                reflectedRuleEditorSessionRegistry(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "The second profile was not bound to the reusable Rules window."
            )
            return
        }

        XCTAssertFalse(
            firstSession
                === secondSession
        )

        let recreatedFirstSession =
            registry.session(
                for:
                    firstProfileID
            )

        XCTAssertFalse(
            firstSession
                === recreatedFirstSession
        )

        let retainedSecondSession =
            registry.session(
                for:
                    secondProfile.id
            )

        XCTAssertTrue(
            secondSession
                === retainedSecondSession
        )
    }

    private func cleanUp(
        _ coordinator:
            AppCoordinator
    ) {
        if let rulesController =
            reflectedRulesWindowController(
                from:
                    coordinator
            )
        {
            if let ruleEditorSession =
                reflectedRuleEditorSession(
                    from:
                        rulesController
                ),
               ruleEditorSession.hasUnsavedChanges
            {
                ruleEditorSession
                    .restoreSavedRules()
            }

            rulesController.close()
        }

        if let homeSession =
            reflectedHomeConfigurationEditorSession(
                from:
                    coordinator
            ),
           homeSession.hasUnsavedChanges
        {
            homeSession
                .restoreSavedSnapshot()
        }

        reflectedMainWindowController(
            from:
                coordinator
        )?
            .close()

        coordinator.stop()
    }

    private func reflectedHomeConfigurationEditorSession(
        from coordinator:
            AppCoordinator
    ) -> HomeConfigurationEditorSession? {
        reflectedValue(
            named:
                "homeConfigurationEditorSession",
            from:
                coordinator,
            as:
                HomeConfigurationEditorSession.self
        )
    }

    private func reflectedRuleEditorSessionRegistry(
        from coordinator:
            AppCoordinator
    ) -> ProfileRuleEditorSessionRegistry? {
        reflectedValue(
            named:
                "ruleEditorSessionRegistry",
            from:
                coordinator,
            as:
                ProfileRuleEditorSessionRegistry.self
        )
    }

    private func reflectedMainWindowController(
        from coordinator:
            AppCoordinator
    ) -> MainWindowController? {
        reflectedValue(
            named:
                "mainWindowController",
            from:
                coordinator,
            as:
                MainWindowController.self
        )
    }

    private func reflectedRulesWindowController(
        from coordinator:
            AppCoordinator
    ) -> RemappingRulesWindowController? {
        reflectedValue(
            named:
                "remappingRulesWindowController",
            from:
                coordinator,
            as:
                RemappingRulesWindowController.self
        )
    }

    private func reflectedRuleEditorSession(
        from controller:
            RemappingRulesWindowController
    ) -> RemappingRuleEditorSession? {
        reflectedValue(
            named:
                "ruleEditorSession",
            from:
                controller,
            as:
                RemappingRuleEditorSession.self
        )
    }

    private func reflectedValue<
        Value
    >(
        named propertyName:
            String,
        from owner:
            Any,
        as valueType:
            Value.Type
    ) -> Value? {
        guard
            let storedValue =
                Mirror(
                    reflecting:
                        owner
                )
                .children
                .first(
                    where: {
                        $0.label
                            == propertyName
                    }
                )?
                .value
        else {
            return nil
        }

        if let directValue =
            storedValue
                as? Value
        {
            return directValue
        }

        let optionalMirror =
            Mirror(
                reflecting:
                    storedValue
            )

        guard
            optionalMirror.displayStyle
                == .optional
        else {
            return nil
        }

        return optionalMirror
            .children
            .first?
            .value
            as? Value
    }
}
