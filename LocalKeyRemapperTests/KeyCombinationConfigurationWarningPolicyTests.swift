//
//  KeyCombinationConfigurationWarningPolicyTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/21/26.
//

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class KeyCombinationConfigurationWarningPolicyTests:
    XCTestCase
{
    func testFnWithF1ReturnsWarning() {
        let warning =
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        fnCombination(
                            keyCode:
                                kVK_F1
                        )
                )

        XCTAssertEqual(
            warning,
            .fnWithFunctionKey
        )
    }

    func testFnWithF12ReturnsWarning() {
        let warning =
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        fnCombination(
                            keyCode:
                                kVK_F12
                        )
                )

        XCTAssertEqual(
            warning,
            .fnWithFunctionKey
        )
    }

    func testAdditionalModifiersDoNotSuppressWarning() {
        let warning =
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        KeyCombination(
                            keyCode:
                                CGKeyCode(
                                    kVK_F6
                                ),
                            modifiers: [
                                .control,
                                .option,
                                .command,
                                .fn
                            ]
                        )
                )

        XCTAssertEqual(
            warning,
            .fnWithFunctionKey
        )
    }

    func testFunctionKeyWithoutFnDoesNotReturnWarning() {
        let warning =
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        KeyCombination(
                            keyCode:
                                CGKeyCode(
                                    kVK_F6
                                ),
                            modifiers: [
                                .command
                            ]
                        )
                )

        XCTAssertNil(
            warning
        )
    }

    func testFnWithRegularKeyDoesNotReturnWarning() {
        let warning =
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        KeyCombination(
                            keyCode:
                                KeyCode.v,
                            modifiers: [
                                .fn
                            ]
                        )
                )

        XCTAssertNil(
            warning
        )
    }

    func testF13IsOutsideIssueWarningRange() {
        XCTAssertFalse(
            KeyCombinationConfigurationWarningPolicy
                .isStandardFunctionKey(
                    CGKeyCode(
                        kVK_F13
                    )
                )
        )
    }

    func testRuleSourceIsInspected() {
        let rule = RemapRule(
            source:
                fnCombination(
                    keyCode:
                        kVK_F4
                ),
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w
                )
        )

        XCTAssertEqual(
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        rule
                ),
            .fnWithFunctionKey
        )
    }

    func testRuleDestinationIsInspected() {
        let rule = RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        KeyCode.v
                ),
            destination:
                fnCombination(
                    keyCode:
                        kVK_F8
                )
        )

        XCTAssertEqual(
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        rule
                ),
            .fnWithFunctionKey
        )
    }

    func testExceptionSourceIsInspected() {
        let remapOverride = RemapOverride(
            source:
                fnCombination(
                    keyCode:
                        kVK_F7
                ),
            action:
                .passThrough
        )

        XCTAssertEqual(
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        remapOverride
                ),
            .fnWithFunctionKey
        )
    }

    func testCustomExceptionDestinationIsInspected() {
        let remapOverride = RemapOverride(
            source:
                KeyCombination(
                    keyCode:
                        KeyCode.v,
                    modifiers: [
                        .command
                    ]
                ),
            action:
                .replaceWith(
                    fnCombination(
                        keyCode:
                            kVK_F10
                    )
                )
        )

        XCTAssertEqual(
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        remapOverride
                ),
            .fnWithFunctionKey
        )
    }

    func testPassThroughExceptionWithoutFnFunctionKeyHasNoWarning() {
        let remapOverride = RemapOverride(
            source:
                KeyCombination(
                    keyCode:
                        KeyCode.v,
                    modifiers: [
                        .command
                    ]
                ),
            action:
                .passThrough
        )

        XCTAssertNil(
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        remapOverride
                )
        )
    }

    func testRuleCollectionInspectsStoredExceptions() {
        let rule = RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        KeyCode.v
                ),
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w
                ),
            matchingMode:
                .preserveModifiers,
            overrides: [
                RemapOverride(
                    source:
                        KeyCombination(
                            keyCode:
                                KeyCode.v,
                            modifiers: [
                                .command
                            ]
                        ),
                    action:
                        .replaceWith(
                            fnCombination(
                                keyCode:
                                    kVK_F11
                            )
                        )
                )
            ]
        )

        XCTAssertEqual(
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for: [
                        rule
                    ]
                ),
            .fnWithFunctionKey
        )
    }

    func testWarningMessageMatchesUserFacingGuidance() {
        XCTAssertEqual(
            KeyCombinationConfigurationWarning
                .fnWithFunctionKey
                .message,
            "Fn combined with a function key may be handled by macOS or the keyboard as a system or media action. This combination may not work consistently on every keyboard."
        )
    }

    private func fnCombination(
        keyCode:
            Int
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                CGKeyCode(
                    keyCode
                ),
            modifiers: [
                .fn
            ]
        )
    }
}
