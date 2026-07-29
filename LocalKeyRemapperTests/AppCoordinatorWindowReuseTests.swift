//
//  AppCoordinatorWindowReuseTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/24/26.
//

import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class AppCoordinatorWindowReuseTests:
    XCTestCase
{
    func testRepeatedRulesWindowRequestsReuseOneControllerAndOneWindow() {
        let coordinator =
            AppCoordinator()

        defer {
            coordinator.stop()
        }

        coordinator.showRemappingRulesWindow()

        guard
            let firstController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "The first rules-window request did not create a controller."
            )
            return
        }

        XCTAssertTrue(
            firstController.window?.isVisible
                == true
        )

        coordinator.showRemappingRulesWindow()

        guard
            let secondController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "The second rules-window request lost the existing controller."
            )
            return
        }

        XCTAssertTrue(
            firstController
                === secondController
        )

        XCTAssertEqual(
            visibleRulesWindowCount,
            1
        )

        firstController.close()
    }

    func testClosingAndReopeningRulesWindowPreservesControllerAndPresentationState() {
        let coordinator =
            AppCoordinator()

        defer {
            coordinator.stop()
        }

        coordinator.showRemappingRulesWindow()

        guard
            let firstController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                ),
            let firstPresentationModel =
                reflectedPresentationModel(
                    from:
                        firstController
                )
        else {
            XCTFail(
                "The rules window or its presentation model was not created."
            )
            return
        }

        _ = firstPresentationModel
            .selectSortColumn(
                .source
            )

        firstPresentationModel
            .toggleConfigurationWarningFilter()

        let expectedSortDescriptor =
            RemappingRulesPresentationModel
                .SortDescriptor(
                    column:
                        .source,
                    direction:
                        .ascending
                )

        XCTAssertEqual(
            firstPresentationModel
                .sortDescriptor,
            expectedSortDescriptor
        )

        XCTAssertTrue(
            firstPresentationModel
                .showsOnlyConfigurationWarnings
        )

        firstController.close()

        XCTAssertFalse(
            firstController.window?.isVisible
                == true
        )

        coordinator.showRemappingRulesWindow()

        guard
            let reopenedController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                ),
            let reopenedPresentationModel =
                reflectedPresentationModel(
                    from:
                        reopenedController
                )
        else {
            XCTFail(
                "The rules window was not restored after reopening."
            )
            return
        }

        XCTAssertTrue(
            firstController
                === reopenedController
        )

        XCTAssertTrue(
            firstPresentationModel
                === reopenedPresentationModel
        )

        XCTAssertEqual(
            reopenedPresentationModel
                .sortDescriptor,
            expectedSortDescriptor
        )

        XCTAssertTrue(
            reopenedPresentationModel
                .showsOnlyConfigurationWarnings
        )

        XCTAssertEqual(
            visibleRulesWindowCount,
            1
        )

        reopenedController.close()
    }

    func testStartCreatesAndRetainsOneHomeConfigurationEditorSession() {
        let coordinator =
            AppCoordinator()

        coordinator.start()

        defer {
            reflectedRulesWindowController(
                from:
                    coordinator
            )?.close()
            reflectedMainWindowController(
                from:
                    coordinator
            )?.close()
            coordinator.stop()
        }

        guard
            let firstSession =
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

        XCTAssertEqual(
            firstSession.savedSnapshot,
            firstSession.draft
        )
        XCTAssertFalse(
            firstSession.hasUnsavedChanges
        )

        coordinator.showMainWindow()

        guard
            let retainedSession =
                reflectedHomeConfigurationEditorSession(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "Reopening Home discarded its editor session."
            )
            return
        }

        XCTAssertTrue(
            firstSession
                === retainedSession
        )
    }

    func testRulesWindowCanOpenProfileThatExistsOnlyInHomeDraft()
        throws
    {
        let coordinator =
            AppCoordinator()

        coordinator.start()

        defer {
            reflectedRulesWindowController(
                from:
                    coordinator
            )?.close()
            reflectedMainWindowController(
                from:
                    coordinator
            )?.close()
            coordinator.stop()
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

        let draftProfile =
            try homeSession.addProfile(
                id:
                    UUID(
                        uuidString:
                            "59234AB2-21ED-42AA-8CD3-BDEEB43E6F37"
                    )!,
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_800_000_000
                    )
            )

        XCTAssertNil(
            homeSession.savedSnapshot.profile(
                id:
                    draftProfile.id
            )
        )

        coordinator.showRemappingRulesWindow(
            for:
                draftProfile.id
        )

        guard
            let rulesController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "The coordinator could not open Rules for a draft-only profile."
            )
            return
        }

        XCTAssertEqual(
            rulesController.window?.title,
            draftProfile.name
        )
        XCTAssertTrue(
            rulesController.window?.isVisible
                == true
        )
    }

    func testDraftProfileRulesInitializeItsIndependentRulesSession()
        throws
    {
        let coordinator =
            AppCoordinator()

        coordinator.start()

        defer {
            reflectedRulesWindowController(
                from:
                    coordinator
            )?.close()
            reflectedMainWindowController(
                from:
                    coordinator
            )?.close()
            coordinator.stop()
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

        let duplicate =
            try homeSession.duplicateProfile(
                id:
                    homeSession.draft.activeProfileID,
                newProfileID:
                    UUID(
                        uuidString:
                            "3F92BBEB-F79F-4215-8E1A-209D99FC3D9E"
                    )!,
                timestamp:
                    Date(
                        timeIntervalSince1970:
                            1_800_000_100
                    )
            )

        coordinator.showRemappingRulesWindow(
            for:
                duplicate.id
        )

        guard
            let rulesController =
                reflectedRulesWindowController(
                    from:
                        coordinator
                ),
            let ruleEditorSession =
                reflectedRuleEditorSession(
                    from:
                        rulesController
                )
        else {
            XCTFail(
                "The draft profile was not bound to a Rules editor session."
            )
            return
        }

        XCTAssertTrue(
            ruleEditorSession.isInitialized
        )
        XCTAssertEqual(
            ruleEditorSession.completeRules
                ?? [],
            duplicate.rules
        )
    }

    private var visibleRulesWindowCount:
        Int
    {
        NSApplication.shared
            .windows
            .filter {
                window in

                window.isVisible
                    && (
                        window.windowController
                            is RemappingRulesWindowController
                    )
            }
            .count
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

    private func reflectedPresentationModel(
        from controller:
            RemappingRulesWindowController
    ) -> RemappingRulesPresentationModel? {
        reflectedValue(
            named:
                "presentationModel",
            from:
                controller,
            as:
                RemappingRulesPresentationModel.self
        )
    }

    /// Reads one private ownership value without widening the production API
    /// solely for tests. The test will fail clearly if the ownership contract
    /// or stored-property name changes.
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
