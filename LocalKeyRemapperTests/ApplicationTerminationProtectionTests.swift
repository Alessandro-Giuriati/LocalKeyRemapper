//
//  ApplicationTerminationProtectionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/3/26.
//

import AppKit
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ApplicationTerminationProtectionTests:
    XCTestCase
{
    func testSummaryReportsNoWorkWhenEveryEditorIsSaved() {
        let summary =
            ApplicationUnsavedChangesSummary(
                hasHomeChanges:
                    false,
                unsavedRuleProfileNames:
                    [],
                hasOpenExceptionsEditor:
                    false
            )

        XCTAssertFalse(
            summary.hasChanges
        )
    }

    func testSummaryDescribesHomeRulesAndOpenExceptionsWork() {
        let summary =
            ApplicationUnsavedChangesSummary(
                hasHomeChanges:
                    true,
                unsavedRuleProfileNames: [
                    "Gaming",
                    "Writing"
                ],
                hasOpenExceptionsEditor:
                    true
            )

        XCTAssertTrue(
            summary.hasChanges
        )

        XCTAssertEqual(
            summary.informativeText,
            "LocalKeyRemapper has unsaved Home changes, unsaved remapping rules in 2 profiles, and an unfinished Custom Exceptions editor. Quitting without saving will discard this work and clear the session-only Undo and Redo history."
        )
    }

    func testSummaryNamesOneRulesProfilePrecisely() {
        let summary =
            ApplicationUnsavedChangesSummary(
                hasHomeChanges:
                    false,
                unsavedRuleProfileNames: [
                    "Profile 2"
                ],
                hasOpenExceptionsEditor:
                    false
            )

        XCTAssertEqual(
            summary.informativeText,
            "LocalKeyRemapper has unsaved remapping rules in “Profile 2”. Quitting without saving will discard this work and clear the session-only Undo and Redo history."
        )
    }

    func testAppDelegateForwardsTerminationRequestToCoordinator() {
        let coordinator =
            LifecycleCoordinatorSpy(
                terminationReply:
                    .terminateCancel
            )

        let delegate =
            AppDelegate(
                appCoordinator:
                    coordinator
            )

        let reply =
            delegate.applicationShouldTerminate(
                NSApplication.shared
            )

        XCTAssertEqual(
            reply,
            .terminateCancel
        )

        XCTAssertEqual(
            coordinator
                .applicationShouldTerminateCallCount,
            1
        )
    }

    @MainActor
    private final class LifecycleCoordinatorSpy:
        ApplicationLifecycleCoordinating
    {
        private let terminationReply:
            NSApplication.TerminateReply

        private(set) var applicationShouldTerminateCallCount =
            0

        init(
            terminationReply:
                NSApplication.TerminateReply
        ) {
            self.terminationReply =
                terminationReply
        }

        func start() {}

        func applicationDidBecomeActive() {}

        func applicationShouldTerminate()
            -> NSApplication.TerminateReply
        {
            applicationShouldTerminateCallCount +=
                1

            return terminationReply
        }

        func showMainWindow() {}

        func stop() {}
    }
}
