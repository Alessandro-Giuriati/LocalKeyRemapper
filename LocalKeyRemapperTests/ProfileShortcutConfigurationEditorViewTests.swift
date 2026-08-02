//
//  ProfileShortcutConfigurationEditorViewTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileShortcutConfigurationEditorViewTests:
    XCTestCase
{
    func testUseDefaultEditorPreservesNilOverride() {
        let defaultConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    nil,
                defaultConfiguration:
                    defaultConfiguration
            )

        XCTAssertEqual(
            view.modeForTesting,
            .useDefault
        )

        XCTAssertEqual(
            view.proposal,
            .complete(
                nil
            )
        )

        XCTAssertEqual(
            view.effectiveConfiguration,
            defaultConfiguration
        )

        XCTAssertFalse(
            view.hasChanges
        )

        XCTAssertFalse(
            view.canApply
        )
    }

    func testExplicitOffEditorRemainsDifferentFromUseDefault() {
        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    .disabled,
                defaultConfiguration:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
            )

        XCTAssertEqual(
            view.modeForTesting,
            .off
        )

        XCTAssertEqual(
            view.proposal,
            .complete(
                .disabled
            )
        )

        XCTAssertEqual(
            view.effectiveConfiguration,
            .disabled
        )
    }

    func testCustomToggleEditorPreservesShortcut() {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    .toggle(
                        shortcut
                    ),
                defaultConfiguration:
                    .disabled
            )

        XCTAssertEqual(
            view.modeForTesting,
            .toggle
        )

        XCTAssertEqual(
            view.proposal,
            .complete(
                .toggle(
                    shortcut
                )
            )
        )

        XCTAssertTrue(
            view.isRowVisibleForTesting(
                .toggle
            )
        )

        XCTAssertFalse(
            view.isRowVisibleForTesting(
                .enable
            )
        )
    }

    func testChangingToSeparateUsesSuggestedShortcuts() {
        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    nil,
                defaultConfiguration:
                    .disabled
            )

        view.setModeForTesting(
            .separate
        )

        XCTAssertEqual(
            view.proposal,
            .complete(
                .separate(
                    enable:
                        ProfileShortcutConfigurationDraft
                            .defaultEnableShortcut,
                    disable:
                        ProfileShortcutConfigurationDraft
                            .defaultDisableShortcut
                )
            )
        )

        XCTAssertTrue(
            view.isRowVisibleForTesting(
                .enable
            )
        )

        XCTAssertTrue(
            view.isRowVisibleForTesting(
                .disable
            )
        )

        XCTAssertTrue(
            view.canApply
        )
    }

    func testClearingRequiredShortcutMakesEditorIncomplete() {
        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    .toggle(
                        makeShortcut(
                            keyCode:
                                KeyCode.r
                        )
                    ),
                defaultConfiguration:
                    .disabled
            )

        view.clearShortcutForTesting(
            .toggle
        )

        XCTAssertEqual(
            view.proposal,
            .incomplete
        )

        XCTAssertNil(
            view.effectiveConfiguration
        )

        XCTAssertEqual(
            view.currentValidationMessage,
            "Choose every shortcut required by the selected mode."
        )

        XCTAssertFalse(
            view.canApply
        )
    }

    func testShortcutWithoutModifierProducesBlockingValidation() {
        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    nil,
                defaultConfiguration:
                    .disabled
            )

        view.setModeForTesting(
            .toggle
        )

        view.setCapturedShortcut(
            KeyCombination(
                keyCode:
                    KeyCode.r
            ),
            for:
                .toggle
        )

        XCTAssertEqual(
            view.currentValidationMessage,
            "Every custom shortcut must contain at least one modifier."
        )

        XCTAssertFalse(
            view.canApply
        )
    }

    func testAdditionalValidationReceivesEffectiveDefaultConfiguration() {
        let defaultConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    .disabled,
                defaultConfiguration:
                    defaultConfiguration
            )

        var receivedConfiguration:
            RemappingShortcutConfiguration?

        view.onAdditionalValidationRequested = {
            configuration in

            receivedConfiguration =
                configuration

            return "Expected blocking message"
        }

        view.setModeForTesting(
            .useDefault
        )

        XCTAssertEqual(
            receivedConfiguration,
            defaultConfiguration
        )

        XCTAssertEqual(
            view.currentValidationMessage,
            "Expected blocking message"
        )

        XCTAssertFalse(
            view.canApply
        )
    }

    func testCapturePromptAndCancellationCallbacksRemainLocal() {
        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    nil,
                defaultConfiguration:
                    .disabled
            )

        var requestedField:
            ProfileShortcutConfigurationEditorView
                .CaptureField?

        var cancellationCount =
            0

        view.onCaptureRequested = {
            field in

            requestedField =
                field
        }

        view.onCaptureCancellationRequested = {
            cancellationCount +=
                1

            view.endCapturePrompt()
        }

        view.setModeForTesting(
            .toggle
        )

        view.onCaptureRequested?(
            .toggle
        )

        XCTAssertEqual(
            requestedField,
            .toggle
        )

        view.beginCapturePrompt(
            for:
                .toggle
        )

        XCTAssertEqual(
            view.activeCaptureField,
            .toggle
        )

        XCTAssertFalse(
            view.canApply
        )

        view.onCaptureCancellationRequested?()

        XCTAssertNil(
            view.activeCaptureField
        )

        XCTAssertEqual(
            cancellationCount,
            2
        )
    }

    func testOverrideEqualToDefaultRemainsExplicitAndUnchanged() {
        let sharedConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.r
            )

        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    sharedConfiguration,
                defaultConfiguration:
                    sharedConfiguration
            )

        XCTAssertEqual(
            view.proposal,
            .complete(
                sharedConfiguration
            )
        )

        XCTAssertEqual(
            view.effectiveConfiguration,
            sharedConfiguration
        )

        XCTAssertFalse(
            view.hasChanges
        )

        view.setModeForTesting(
            .useDefault
        )

        XCTAssertEqual(
            view.proposal,
            .complete(
                nil
            )
        )

        XCTAssertTrue(
            view.hasChanges
        )

        XCTAssertTrue(
            view.canApply
        )
    }

    private func makeToggleConfiguration(
        keyCode:
            CGKeyCode
    ) -> RemappingShortcutConfiguration {
        .toggle(
            makeShortcut(
                keyCode:
                    keyCode
            )
        )
    }

    private func makeShortcut(
        keyCode:
            CGKeyCode
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
}
