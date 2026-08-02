//
//  GlobalShortcutSettingsViewTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/18/26.
//

import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class GlobalShortcutSettingsViewTests:
    XCTestCase
{
    func testIndependentSaveAndCancelButtonsAreRemoved() {
        let view =
            makeView()

        XCTAssertNil(
            button(
                withIdentifier:
                    "globalShortcut.save",
                in:
                    view
            )
        )

        XCTAssertNil(
            button(
                withIdentifier:
                    "globalShortcut.cancel",
                in:
                    view
            )
        )
    }

    func testCapturedShortcutReportsCompleteConfigurationToHome() {
        let view =
            makeView()

        let capturedShortcut =
            KeyCombination(
                keyCode:
                    KeyCode.e,
                modifiers: [
                    .control,
                    .command
                ]
            )

        var reportedConfigurations:
            [RemappingShortcutConfiguration] = []

        view.onConfigurationChangeRequested = {
            configuration in

            reportedConfigurations.append(
                configuration
            )
        }

        view.setCapturedShortcut(
            capturedShortcut,
            for:
                .toggle
        )

        XCTAssertEqual(
            reportedConfigurations,
            [
                .toggle(
                    capturedShortcut
                )
            ]
        )
    }

    func testExternalLoadDoesNotReportAUserChange() {
        let view =
            makeView()

        var reportCount =
            0

        view.onConfigurationChangeRequested = {
            _ in

            reportCount +=
                1
        }

        let configuration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        KeyCombination(
                            keyCode:
                                KeyCode.e,
                            modifiers: [
                                .control,
                                .option,
                                .command
                            ]
                        ),
                    disable:
                        KeyCombination(
                            keyCode:
                                KeyCode.d,
                            modifiers: [
                                .control,
                                .option,
                                .command
                            ]
                        )
                )

        view.load(
            configuration:
                configuration
        )

        XCTAssertEqual(
            reportCount,
            0
        )

        XCTAssertEqual(
            view.currentConfiguration,
            configuration
        )

        XCTAssertFalse(
            view.hasTransientEditorChanges
        )
    }

    func testChangingModeReportsTheNewCompleteConfiguration() throws {
        let view =
            makeView()

        var reportedConfiguration:
            RemappingShortcutConfiguration?

        view.onConfigurationChangeRequested = {
            configuration in

            reportedConfiguration =
                configuration
        }

        let modeControl =
            try XCTUnwrap(
                segmentedControl(
                    withIdentifier:
                        "globalShortcut.mode",
                    in:
                        view
                )
            )

        modeControl.selectedSegment =
            0

        _ = modeControl.sendAction(
            modeControl.action,
            to:
                modeControl.target
        )

        XCTAssertEqual(
            reportedConfiguration,
            .disabled
        )
    }

    func testClearingRequiredShortcutKeepsIncompleteStateLocal() {
        let view =
            makeView()

        var reportCount =
            0

        view.onConfigurationChangeRequested = {
            _ in

            reportCount +=
                1
        }

        button(
            withIdentifier:
                "globalShortcut.toggle.clear",
            in:
                view
        )?
        .performClick(
            nil
        )

        XCTAssertNil(
            view.currentConfiguration
        )

        XCTAssertTrue(
            view.hasTransientEditorChanges
        )

        XCTAssertEqual(
            view.currentValidationMessage,
            "Choose every shortcut required by the selected mode."
        )

        XCTAssertEqual(
            reportCount,
            0
        )
    }

    func testRowCancelIsDisplayedDuringCaptureAndRequestsCancellation() {
        let view =
            makeView()

        var cancellationWasRequested =
            false

        view.onCaptureCancellationRequested =
        {
            cancellationWasRequested =
                true
        }

        let rowCancelButton =
            button(
                withIdentifier:
                    "globalShortcut.toggle.cancel",
                in:
                    view
            )

        view.beginCapturePrompt(
            for:
                .toggle
        )

        XCTAssertEqual(
            rowCancelButton?
                .isHidden,
            false
        )

        rowCancelButton?
            .performClick(
                nil
            )

        XCTAssertTrue(
            cancellationWasRequested
        )
    }

    func testStructurallyInvalidShortcutExposesValidationMessage() {
        let view =
            makeView()

        view.setCapturedShortcut(
            KeyCombination(
                keyCode:
                    KeyCode.e
            ),
            for:
                .toggle
        )

        XCTAssertEqual(
            view.currentValidationMessage,
            "Every global shortcut must contain at least one modifier."
        )
    }

    private func makeView()
        -> GlobalShortcutSettingsView
    {
        GlobalShortcutSettingsView(
            configuration:
                .toggle(
                    AppPreferences
                        .defaultToggleShortcut
                )
        )
    }

    private func button(
        withIdentifier identifier:
            String,
        in view:
            NSView
    ) -> NSButton? {
        matchingView(
            withIdentifier:
                identifier,
            in:
                view,
            as:
                NSButton.self
        )
    }

    private func segmentedControl(
        withIdentifier identifier:
            String,
        in view:
            NSView
    ) -> NSSegmentedControl? {
        matchingView(
            withIdentifier:
                identifier,
            in:
                view,
            as:
                NSSegmentedControl.self
        )
    }

    private func matchingView<
        View: NSView
    >(
        withIdentifier identifier:
            String,
        in view:
            NSView,
        as viewType:
            View.Type
    ) -> View? {
        if
            let matchingView =
                view as? View,
            matchingView.identifier?
                .rawValue
                == identifier
        {
            return matchingView
        }

        for subview in
            view.subviews
        {
            if let matchingView =
                matchingView(
                    withIdentifier:
                        identifier,
                    in:
                        subview,
                    as:
                        viewType
                )
            {
                return matchingView
            }
        }

        return nil
    }
}
