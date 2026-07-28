//
//  RemappingShortcutRuleConflictPolicyTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/28/26.
//

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class RemappingShortcutRuleConflictPolicyTests:
    XCTestCase
{
    func testDisabledShortcutConfigurationNeverConflictsOrWarns() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            exactRule(
                source:
                    configuredShortcut
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .disabled
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .disabled
        )
    }

    func testExactRuleRejectsToggleShortcut() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            exactRule(
                source:
                    configuredShortcut
            )

        assertConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testSeparateEnableConflictIdentifiesEnableAction() {
        let enableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let disableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let rule =
            exactRule(
                source:
                    enableShortcut
            )

        assertConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .separate(
                    enable:
                        enableShortcut,
                    disable:
                        disableShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .enable,
            expectedShortcut:
                enableShortcut
        )
    }

    func testSeparateDisableConflictIdentifiesDisableAction() {
        let enableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let disableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let rule =
            exactRule(
                source:
                    disableShortcut
            )

        assertConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .separate(
                    enable:
                        enableShortcut,
                    disable:
                        disableShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .disable,
            expectedShortcut:
                disableShortcut
        )
    }

    func testExactRuleWithDifferentModifiersDoesNotConflictOrWarn() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r,
                modifiers:
                    [
                        .command
                    ]
            )

        let rule =
            exactRule(
                source:
                    makeShortcut(
                        keyCode:
                            KeyCode.r,
                        modifiers:
                            [
                                .control
                            ]
                    )
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testPreserveModifiersRuleAllowsShortcutAndProducesWarning() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.r,
                destinationKeyCode:
                    KeyCode.w
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertSingleWarning(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )
    }

    func testPreserveWarningsIdentifySeparateEnableAndDisableActions() {
        let enableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let disableShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let rules = [
            preserveRule(
                sourceKeyCode:
                    KeyCode.e,
                destinationKeyCode:
                    CGKeyCode(kVK_ANSI_F)
            ),
            preserveRule(
                sourceKeyCode:
                    KeyCode.d,
                destinationKeyCode:
                    CGKeyCode(kVK_ANSI_M)
            )
        ]

        let configuration =
            RemappingShortcutConfiguration.separate(
                enable:
                    enableShortcut,
                disable:
                    disableShortcut
            )

        assertNoConflict(
            rules:
                rules,
            configuration:
                configuration
        )

        let warnings =
            RemappingShortcutRuleConflictPolicy
                .warnings(
                    rules:
                        rules,
                    shortcutConfiguration:
                        configuration
                )

        XCTAssertEqual(
            warnings.count,
            2
        )

        XCTAssertEqual(
            warnings[0],
            RemappingShortcutRuleWarning(
                ruleIndex:
                    0,
                action:
                    .enable,
                shortcut:
                    enableShortcut
            )
        )

        XCTAssertEqual(
            warnings[1],
            RemappingShortcutRuleWarning(
                ruleIndex:
                    1,
                action:
                    .disable,
                shortcut:
                    disableShortcut
            )
        )
    }

    func testEnabledPassThroughExceptionConflicts() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.r,
                destinationKeyCode:
                    KeyCode.w,
                overrides: [
                    RemapOverride(
                        source:
                            configuredShortcut,
                        action:
                            .passThrough,
                        isEnabled:
                            true
                    )
                ]
            )

        assertConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testDisabledPassThroughExceptionAllowsPreserveWarning() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.r,
                destinationKeyCode:
                    KeyCode.w,
                overrides: [
                    RemapOverride(
                        source:
                            configuredShortcut,
                        action:
                            .passThrough,
                        isEnabled:
                            false
                    )
                ]
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertSingleWarning(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )
    }

    func testEnabledReplacementExceptionConflicts() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let replacement =
            makeShortcut(
                keyCode:
                    KeyCode.b
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.r,
                destinationKeyCode:
                    KeyCode.w,
                overrides: [
                    RemapOverride(
                        source:
                            configuredShortcut,
                        action:
                            .replaceWith(
                                replacement
                            ),
                        isEnabled:
                            true
                    )
                ]
            )

        assertConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testDisabledReplacementExceptionAllowsPreserveWarning() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let replacement =
            makeShortcut(
                keyCode:
                    KeyCode.b
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.r,
                destinationKeyCode:
                    KeyCode.w,
                overrides: [
                    RemapOverride(
                        source:
                            configuredShortcut,
                        action:
                            .replaceWith(
                                replacement
                            ),
                        isEnabled:
                            false
                    )
                ]
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertSingleWarning(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )
    }

    func testExceptionDestinationEqualToShortcutDoesNotConflict() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let exceptionSource =
            makeShortcut(
                keyCode:
                    KeyCode.v
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.w,
                overrides: [
                    RemapOverride(
                        source:
                            exceptionSource,
                        action:
                            .replaceWith(
                                configuredShortcut
                            ),
                        isEnabled:
                            true
                    )
                ]
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testDisabledRuleIsIgnored() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.r,
                destinationKeyCode:
                    KeyCode.w,
                isEnabled:
                    false
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testDestinationDoesNotConflictWhenReverseIsDisabled() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            RemapRule(
                source:
                    KeyCombination(
                        keyCode:
                            KeyCode.v
                    ),
                destination:
                    configuredShortcut,
                matchingMode:
                    .exact,
                overrides:
                    [],
                isEnabled:
                    true,
                isBidirectional:
                    false
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testExactReverseDirectionConflicts() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let source =
            makeShortcut(
                keyCode:
                    KeyCode.v
            )

        let rule =
            RemapRule(
                source:
                    source,
                destination:
                    configuredShortcut,
                matchingMode:
                    .exact,
                overrides:
                    [],
                isEnabled:
                    true,
                isBidirectional:
                    true
            )

        assertConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )
    }

    func testPreserveReverseDirectionAllowsShortcutAndProducesWarning() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.r,
                isBidirectional:
                    true
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertSingleWarning(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )
    }

    func testMirroredEnabledPassThroughExceptionConflicts() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let forwardExceptionSource =
            makeShortcut(
                keyCode:
                    KeyCode.v
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.r,
                overrides: [
                    RemapOverride(
                        source:
                            forwardExceptionSource,
                        action:
                            .passThrough,
                        isEnabled:
                            true
                    )
                ],
                isBidirectional:
                    true
            )

        assertConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )

        assertNoWarnings(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )
    }

    func testMirroredDisabledPassThroughExceptionAllowsReverseWarning() {
        let configuredShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let forwardExceptionSource =
            makeShortcut(
                keyCode:
                    KeyCode.v
            )

        let rule =
            preserveRule(
                sourceKeyCode:
                    KeyCode.v,
                destinationKeyCode:
                    KeyCode.r,
                overrides: [
                    RemapOverride(
                        source:
                            forwardExceptionSource,
                        action:
                            .passThrough,
                        isEnabled:
                            false
                    )
                ],
                isBidirectional:
                    true
            )

        assertNoConflict(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                )
        )

        assertSingleWarning(
            rules:
                [
                    rule
                ],
            configuration:
                .toggle(
                    configuredShortcut
                ),
            expectedRuleIndex:
                0,
            expectedAction:
                .toggle,
            expectedShortcut:
                configuredShortcut
        )
    }

    func testWarningMetadataUsesExpectedTitlesAndBehaviors() {
        let toggleWarning =
            RemappingShortcutRuleWarning(
                ruleIndex:
                    0,
                action:
                    .toggle,
                shortcut:
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    )
            )

        let enableWarning =
            RemappingShortcutRuleWarning(
                ruleIndex:
                    0,
                action:
                    .enable,
                shortcut:
                    makeShortcut(
                        keyCode:
                            KeyCode.e
                    )
            )

        let disableWarning =
            RemappingShortcutRuleWarning(
                ruleIndex:
                    0,
                action:
                    .disable,
                shortcut:
                    makeShortcut(
                        keyCode:
                            KeyCode.d
                    )
            )

        XCTAssertEqual(
            toggleWarning.shortcutTitle,
            "Toggle Remapping"
        )

        XCTAssertEqual(
            toggleWarning.reservedBehaviorDescription,
            "toggle remapping"
        )

        XCTAssertEqual(
            enableWarning.shortcutTitle,
            "Enable Remapping"
        )

        XCTAssertEqual(
            enableWarning.reservedBehaviorDescription,
            "enable remapping"
        )

        XCTAssertEqual(
            disableWarning.shortcutTitle,
            "Disable Remapping"
        )

        XCTAssertEqual(
            disableWarning.reservedBehaviorDescription,
            "disable remapping"
        )
    }

    private func assertNoConflict(
        rules:
            [RemapRule],
        configuration:
            RemappingShortcutConfiguration,
        file:
            StaticString = #filePath,
        line:
            UInt = #line
    ) {
        XCTAssertNoThrow(
            try RemappingShortcutRuleConflictPolicy
                .validate(
                    rules:
                        rules,
                    shortcutConfiguration:
                        configuration
                ),
            file:
                file,
            line:
                line
        )
    }

    private func assertConflict(
        rules:
            [RemapRule],
        configuration:
            RemappingShortcutConfiguration,
        expectedRuleIndex:
            Int,
        expectedAction:
            GlobalShortcutAction,
        expectedShortcut:
            KeyCombination,
        file:
            StaticString = #filePath,
        line:
            UInt = #line
    ) {
        XCTAssertThrowsError(
            try RemappingShortcutRuleConflictPolicy
                .validate(
                    rules:
                        rules,
                    shortcutConfiguration:
                        configuration
                ),
            file:
                file,
            line:
                line
        ) {
            error in

            guard
                let conflict =
                    error as?
                        RemappingShortcutRuleConflict
            else {
                XCTFail(
                    "Expected RemappingShortcutRuleConflict, received \(error).",
                    file:
                        file,
                    line:
                        line
                )
                return
            }

            XCTAssertEqual(
                conflict.ruleIndex,
                expectedRuleIndex,
                file:
                    file,
                line:
                    line
            )

            XCTAssertEqual(
                conflict.action,
                expectedAction,
                file:
                    file,
                line:
                    line
            )

            XCTAssertEqual(
                conflict.shortcut,
                expectedShortcut,
                file:
                    file,
                line:
                    line
            )
        }
    }

    private func assertSingleWarning(
        rules:
            [RemapRule],
        configuration:
            RemappingShortcutConfiguration,
        expectedRuleIndex:
            Int,
        expectedAction:
            GlobalShortcutAction,
        expectedShortcut:
            KeyCombination,
        file:
            StaticString = #filePath,
        line:
            UInt = #line
    ) {
        let warnings =
            RemappingShortcutRuleConflictPolicy
                .warnings(
                    rules:
                        rules,
                    shortcutConfiguration:
                        configuration
                )

        XCTAssertEqual(
            warnings.count,
            1,
            file:
                file,
            line:
                line
        )

        guard let warning = warnings.first else {
            return
        }

        XCTAssertEqual(
            warning.ruleIndex,
            expectedRuleIndex,
            file:
                file,
            line:
                line
        )

        XCTAssertEqual(
            warning.action,
            expectedAction,
            file:
                file,
            line:
                line
        )

        XCTAssertEqual(
            warning.shortcut,
            expectedShortcut,
            file:
                file,
            line:
                line
        )
    }

    private func assertNoWarnings(
        rules:
            [RemapRule],
        configuration:
            RemappingShortcutConfiguration,
        file:
            StaticString = #filePath,
        line:
            UInt = #line
    ) {
        XCTAssertTrue(
            RemappingShortcutRuleConflictPolicy
                .warnings(
                    rules:
                        rules,
                    shortcutConfiguration:
                        configuration
                )
                .isEmpty,
            file:
                file,
            line:
                line
        )
    }

    private func exactRule(
        source:
            KeyCombination,
        isEnabled:
            Bool = true
    ) -> RemapRule {
        RemapRule(
            source:
                source,
            destination:
                makeShortcut(
                    keyCode:
                        KeyCode.w,
                    modifiers:
                        source.modifiers
                ),
            matchingMode:
                .exact,
            overrides:
                [],
            isEnabled:
                isEnabled,
            isBidirectional:
                false
        )
    }

    private func preserveRule(
        sourceKeyCode:
            CGKeyCode,
        destinationKeyCode:
            CGKeyCode,
        overrides:
            [RemapOverride] = [],
        isEnabled:
            Bool = true,
        isBidirectional:
            Bool = false
    ) -> RemapRule {
        RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        sourceKeyCode
                ),
            destination:
                KeyCombination(
                    keyCode:
                        destinationKeyCode
                ),
            matchingMode:
                .preserveModifiers,
            overrides:
                overrides,
            isEnabled:
                isEnabled,
            isBidirectional:
                isBidirectional
        )
    }

    private func makeShortcut(
        keyCode:
            CGKeyCode,
        modifiers:
            KeyModifiers = [
                .control,
                .option,
                .command
            ]
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers:
                modifiers
        )
    }
}
