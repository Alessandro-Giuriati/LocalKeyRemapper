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
    func testSaveButtonUsesAccentColorOnlyWhenEnabled() {
        let view =
            makeView()

        let saveButton =
            button(
                withIdentifier:
                    "globalShortcut.save",
                in:
                    view
            )

        XCTAssertNotNil(
            saveButton
        )

        XCTAssertEqual(
            saveButton?
                .isEnabled,
            false
        )

        XCTAssertNil(
            saveButton?
                .bezelColor
        )

        view.setCapturedShortcut(
            KeyCombination(
                keyCode:
                    KeyCode.e,
                modifiers: [
                    .control,
                    .command
                ]
            ),
            for:
                .toggle
        )

        XCTAssertEqual(
            saveButton?
                .isEnabled,
            true
        )

        XCTAssertTrue(
            saveButton?
                .bezelColor?
                .isEqual(
                    NSColor
                        .controlAccentColor
                ) == true
        )

        view.discardChanges()

        XCTAssertEqual(
            saveButton?
                .isEnabled,
            false
        )

        XCTAssertNil(
            saveButton?
                .bezelColor
        )
    }

    func testCancelButtonIsAdjacentToSaveButton() {
        let view =
            makeView()

        let saveButton =
            button(
                withIdentifier:
                    "globalShortcut.save",
                in:
                    view
            )

        let cancelButton =
            button(
                withIdentifier:
                    "globalShortcut.cancel",
                in:
                    view
            )

        XCTAssertNotNil(
            saveButton
        )

        XCTAssertNotNil(
            cancelButton
        )

        XCTAssertTrue(
            saveButton?
                .superview
                === cancelButton?
                    .superview
        )

        let arrangedSubviews =
            (
                saveButton?
                    .superview as?
                        NSStackView
            )?
            .arrangedSubviews

        XCTAssertEqual(
            arrangedSubviews?
                .firstIndex {
                    $0 === saveButton
                },
            0
        )

        XCTAssertEqual(
            arrangedSubviews?
                .firstIndex {
                    $0 === cancelButton
                },
            1
        )
    }

    func testClearCanBeUndoneWithCancel() {
        let view =
            makeView()

        let recordButton =
            button(
                withIdentifier:
                    "globalShortcut.toggle.record",
                in:
                    view
            )

        let clearButton =
            button(
                withIdentifier:
                    "globalShortcut.toggle.clear",
                in:
                    view
            )

        let cancelButton =
            button(
                withIdentifier:
                    "globalShortcut.cancel",
                in:
                    view
            )

        let savedTitle =
            recordButton?
                .title

        clearButton?
            .performClick(
                nil
            )

        XCTAssertTrue(
            view.hasUnsavedChanges
        )

        XCTAssertEqual(
            recordButton?
                .title,
            "Choose Shortcut…"
        )

        XCTAssertEqual(
            cancelButton?
                .isEnabled,
            true
        )

        cancelButton?
            .performClick(
                nil
            )

        XCTAssertFalse(
            view.hasUnsavedChanges
        )

        XCTAssertEqual(
            recordButton?
                .title,
            savedTitle
        )

        XCTAssertEqual(
            cancelButton?
                .isEnabled,
            false
        )
    }

    func testCancelEndsCaptureAndRestoresSavedConfiguration() {
        let view =
            makeView()

        var cancellationWasRequested =
            false

        view.onCaptureCancellationRequested =
        {
            cancellationWasRequested =
                true
        }

        let cancelButton =
            button(
                withIdentifier:
                    "globalShortcut.cancel",
                in:
                    view
            )

        view.beginCapturePrompt(
            for:
                .toggle
        )

        XCTAssertEqual(
            cancelButton?
                .isEnabled,
            true
        )

        cancelButton?
            .performClick(
                nil
            )

        XCTAssertTrue(
            cancellationWasRequested
        )

        XCTAssertNil(
            view.activeCaptureField
        )

        XCTAssertFalse(
            view.hasUnsavedChanges
        )

        XCTAssertEqual(
            cancelButton?
                .isEnabled,
            false
        )
    }

    func testRowLevelCancelIsNeverDisplayed() {
        let view =
            makeView()

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
            true
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
        if
            let button =
                view as?
                    NSButton,
            button.identifier?
                .rawValue
                == identifier
        {
            return button
        }

        for subview in
            view.subviews
        {
            if let matchingButton =
                button(
                    withIdentifier:
                        identifier,
                    in:
                        subview
                )
            {
                return matchingButton
            }
        }

        return nil
    }
}
