//
//  HomeWindowResourceLifecycleTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/4/26.
//

import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class HomeWindowResourceLifecycleTests:
    XCTestCase
{
    func testClosingAndReopeningHomeReleasesWindowAndPreservesSessionHistory() {
        let coordinator =
            AppCoordinator()

        coordinator.start()

        defer {
            reflectedMainWindowController(
                from:
                    coordinator
            )?
                .close()

            coordinator.stop()
        }

        guard
            let editorSession =
                reflectedHomeConfigurationEditorSession(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "Starting the coordinator did not create the shared Home editor session."
            )
            return
        }

        var firstController =
            reflectedMainWindowController(
                from:
                    coordinator
            )

        guard
            firstController != nil
        else {
            XCTFail(
                "Starting the coordinator did not create the Home window controller."
            )
            return
        }

        let savedLaunchBehavior =
            editorSession
                .draft
                .launchBehavior

        let alternateLaunchBehavior:
            RemappingLaunchBehavior =
                savedLaunchBehavior
                    == .alwaysOn
                        ? .alwaysOff
                        : .alwaysOn

        // Create one reversible Home action, then Undo it. The draft is clean,
        // so closing Home requires no alert, while Redo history still has useful
        // session-only state that must survive the UI release.
        editorSession.setLaunchBehavior(
            alternateLaunchBehavior
        )

        XCTAssertTrue(
            editorSession
                .hasUnsavedChanges
        )

        XCTAssertTrue(
            editorSession
                .canUndo
        )

        editorSession.undo()

        XCTAssertFalse(
            editorSession
                .hasUnsavedChanges
        )

        XCTAssertTrue(
            editorSession
                .canRedo
        )

        XCTAssertNotNil(
            editorSession
                .onChange
        )

        let firstControllerIdentifier =
            ObjectIdentifier(
                firstController!
            )

        let closedWindow =
            firstController?
                .window

        firstController?
            .close()

        // The coordinator releases its heavy Home presentation ownership as
        // soon as the normal close callback is delivered.
        XCTAssertNil(
            reflectedMainWindowController(
                from:
                    coordinator
            )
        )

        XCTAssertNil(
            reflectedHomeProfileShortcutSheetCoordinator(
                from:
                    coordinator
            )
        )

        // The closed UI detaches from the shared editor session. A replacement
        // controller will install its own callback when Home is reopened.
        XCTAssertNil(
            editorSession
                .onChange
        )

        // The expensive Home hierarchy is detached synchronously during the
        // close callback. AppKit may retain the lightweight NSWindow shell, and
        // XCTest may retain the controller temporarily; neither is part of the
        // resource contract being tested.
        XCTAssertNil(
            closedWindow?
                .contentView
        )

        firstController =
            nil

        coordinator.showMainWindow()

        guard
            let reopenedController =
                reflectedMainWindowController(
                    from:
                        coordinator
                ),
            let reopenedSession =
                reflectedHomeConfigurationEditorSession(
                    from:
                        coordinator
                )
        else {
            XCTFail(
                "Reopening Home did not recreate its controller with the shared editor session."
            )
            return
        }

        XCTAssertTrue(
            reopenedController
                .window?
                .isVisible
                == true
        )

        // Reopening Home must create a new presentation controller.
        XCTAssertNotEqual(
            ObjectIdentifier(
                reopenedController
            ),
            firstControllerIdentifier
        )

        XCTAssertTrue(
            reopenedSession
                === editorSession
        )

        XCTAssertTrue(
            editorSession
                .canRedo
        )

        XCTAssertNotNil(
            editorSession
                .onChange
        )

        editorSession.redo()

        XCTAssertEqual(
            editorSession
                .draft
                .launchBehavior,
            alternateLaunchBehavior
        )

        XCTAssertTrue(
            editorSession
                .hasUnsavedChanges
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

    private func reflectedHomeProfileShortcutSheetCoordinator(
        from coordinator:
            AppCoordinator
    ) -> HomeProfileShortcutSheetCoordinator? {
        reflectedValue(
            named:
                "homeProfileShortcutSheetCoordinator",
            from:
                coordinator,
            as:
                HomeProfileShortcutSheetCoordinator.self
        )
    }

    private func reflectedValue<Value>(
        named name:
            String,
        from source:
            Any,
        as type:
            Value.Type
    ) -> Value? {
        var currentMirror:
            Mirror? =
                Mirror(
                    reflecting:
                        source
                )

        while let mirror =
            currentMirror
        {
            for child in mirror.children
            where child.label == name {
                if let value =
                    child.value as? Value
                {
                    return value
                }

                let optionalMirror =
                    Mirror(
                        reflecting:
                            child.value
                    )

                if optionalMirror.displayStyle
                    == .optional,
                   let wrappedValue =
                        optionalMirror
                            .children
                            .first?
                            .value as? Value
                {
                    return wrappedValue
                }

                return nil
            }

            currentMirror =
                mirror
                    .superclassMirror
        }

        return nil
    }
}
