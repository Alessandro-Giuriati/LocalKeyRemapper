//
//  BidirectionalRemappingValidationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/26/26.
//

import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class BidirectionalRemappingValidationTests:
    XCTestCase
{
    func testValidatorRejectsExactAndPreserveOnSamePhysicalKeyWhenReverseIsDisabled() {
        let commandW =
            combination(
                KeyCode.w,
                modifiers:
                    [.command]
            )

        let rules = [
            RemapRule(
                source:
                    commandW,
                destination:
                    combination(
                        KeyCode.b
                    ),
                matchingMode:
                    .exact
            ),
            RemapRule(
                source:
                    combination(
                        KeyCode.w
                    ),
                destination:
                    combination(
                        KeyCode.j
                    ),
                matchingMode:
                    .preserveModifiers
            )
        ]

        assertValidationError(
            .duplicateSourceCombination(
                commandW
            ),
            rules:
                rules
        )
    }

    func testValidatorRejectsGeneratedPreserveReverseSourceConflictingWithExactRule() {
        let conflictingSource =
            combination(
                KeyCode.w
            )

        let rules = [
            preserveRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isBidirectional:
                    true
            ),
            exactRule(
                source:
                    KeyCode.w,
                destination:
                    KeyCode.b
            )
        ]

        assertValidationError(
            .duplicateSourceCombination(
                conflictingSource
            ),
            rules:
                rules
        )
    }

    func testValidatorRejectsGeneratedExactReverseSourceConflictingWithPreserveRule() {
        let conflictingSource =
            combination(
                KeyCode.w
            )

        let rules = [
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isBidirectional:
                    true
            ),
            preserveRule(
                source:
                    KeyCode.w,
                destination:
                    KeyCode.b
            )
        ]

        assertValidationError(
            .duplicateSourceCombination(
                conflictingSource
            ),
            rules:
                rules
        )
    }

    func testValidatorRejectsDuplicateGeneratedExactReverseSource() {
        let rules = [
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isBidirectional:
                    true
            ),
            exactRule(
                source:
                    KeyCode.w,
                destination:
                    KeyCode.b
            )
        ]

        assertValidationError(
            .duplicateSourceKey(
                KeyCode.w
            ),
            rules:
                rules
        )
    }

    func testValidatorRejectsDuplicateGeneratedPreserveReverseSource() {
        let rules = [
            preserveRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isBidirectional:
                    true
            ),
            preserveRule(
                source:
                    KeyCode.w,
                destination:
                    KeyCode.b
            )
        ]

        assertValidationError(
            .duplicatePreservingSourceKey(
                KeyCode.w
            ),
            rules:
                rules
        )
    }

    func testValidatorRejectsMirroredExceptionThatBecomesIdentityReplacement() {
        let commandV =
            combination(
                KeyCode.v,
                modifiers: [.command]
            )

        let commandW =
            combination(
                KeyCode.w,
                modifiers: [.command]
            )

        let rule =
            RemapRule(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source:
                            commandV,
                        action:
                            .replaceWith(
                                commandW
                            )
                    )
                ],
                isBidirectional:
                    true
            )

        assertValidationError(
            .identicalSourceAndDestinationCombination(
                commandW
            ),
            rules:
                [
                    rule
                ]
        )
    }

    func testLiveAssessmentMarksBothRulesForPreserveReverseVersusExactConflict() {
        let reverseItem =
            editorItem(
                from:
                    preserveRule(
                        source:
                            KeyCode.v,
                        destination:
                            KeyCode.w,
                        isBidirectional:
                            true
                    )
            )

        let exactItem =
            editorItem(
                from:
                    exactRule(
                        source:
                            KeyCode.w,
                        destination:
                            KeyCode.b
                    )
            )

        let assessment =
            RemappingRulesValidationAssessment(
                items: [
                    reverseItem,
                    exactItem
                ]
            )

        assertDuplicateSourceIssue(
            for:
                reverseItem,
            in:
                assessment
        )

        assertDuplicateSourceIssue(
            for:
                exactItem,
            in:
                assessment
        )

        XCTAssertEqual(
            assessment.primaryIssue,
            .duplicateSource
        )
    }

    func testLiveAssessmentMarksBothRulesForExactReverseVersusPreserveConflict() {
        let reverseItem =
            editorItem(
                from:
                    exactRule(
                        source:
                            KeyCode.v,
                        destination:
                            KeyCode.w,
                        isBidirectional:
                            true
                    )
            )

        let preserveItem =
            editorItem(
                from:
                    preserveRule(
                        source:
                            KeyCode.w,
                        destination:
                            KeyCode.b
                    )
            )

        let assessment =
            RemappingRulesValidationAssessment(
                items: [
                    reverseItem,
                    preserveItem
                ]
            )

        assertDuplicateSourceIssue(
            for:
                reverseItem,
            in:
                assessment
        )

        assertDuplicateSourceIssue(
            for:
                preserveItem,
            in:
                assessment
        )
    }

    func testLiveAssessmentMarksBothRulesForDuplicateGeneratedExactReverseSource() {
        let reverseItem =
            editorItem(
                from:
                    exactRule(
                        source:
                            KeyCode.v,
                        destination:
                            KeyCode.w,
                        isBidirectional:
                            true
                    )
            )

        let explicitItem =
            editorItem(
                from:
                    exactRule(
                        source:
                            KeyCode.w,
                        destination:
                            KeyCode.b
                    )
            )

        let assessment =
            RemappingRulesValidationAssessment(
                items: [
                    reverseItem,
                    explicitItem
                ]
            )

        XCTAssertEqual(
            assessment.invalidItemIDs,
            Set(
                [
                    reverseItem.id,
                    explicitItem.id
                ]
            )
        )

        assertDuplicateSourceIssue(
            for:
                reverseItem,
            in:
                assessment
        )

        assertDuplicateSourceIssue(
            for:
                explicitItem,
            in:
                assessment
        )
    }

    func testLiveAssessmentMarksMirroredExceptionIdentityOnOwningRule() {
        let commandV =
            combination(
                KeyCode.v,
                modifiers: [.command]
            )

        let commandW =
            combination(
                KeyCode.w,
                modifiers: [.command]
            )

        let item =
            editorItem(
                from:
                    RemapRule(
                        source:
                            combination(
                                KeyCode.v
                            ),
                        destination:
                            combination(
                                KeyCode.w
                            ),
                        matchingMode:
                            .preserveModifiers,
                        overrides: [
                            RemapOverride(
                                source:
                                    commandV,
                                action:
                                    .replaceWith(
                                        commandW
                                    )
                            )
                        ],
                        isBidirectional:
                            true
                    )
            )

        let assessment =
            RemappingRulesValidationAssessment(
                items: [
                    item
                ]
            )

        XCTAssertEqual(
            assessment.issues(
                forRuleID:
                    item.id
            ),
            [
                .identicalSourceAndDestination
            ]
        )
    }

    func testLiveAssessmentMarksNormalExactAndPreserveOverlapWithoutReverse() {
        let exactItem =
            editorItem(
                from:
                    RemapRule(
                        source:
                            combination(
                                KeyCode.w,
                                modifiers:
                                    [.command]
                            ),
                        destination:
                            combination(
                                KeyCode.b
                            ),
                        matchingMode:
                            .exact
                    )
            )

        let preserveItem =
            editorItem(
                from:
                    preserveRule(
                        source:
                            KeyCode.w,
                        destination:
                            KeyCode.j
                    )
            )

        let assessment =
            RemappingRulesValidationAssessment(
                items: [
                    exactItem,
                    preserveItem
                ]
            )

        assertDuplicateSourceIssue(
            for:
                exactItem,
            in:
                assessment
        )

        assertDuplicateSourceIssue(
            for:
                preserveItem,
            in:
                assessment
        )

        XCTAssertEqual(
            assessment.primaryIssue,
            .duplicateSource
        )
    }

    func testValidatorAllowsDuplicateSourceWhenOneRuleIsDisabled()
        throws
    {
        let rules = [
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w
            ),
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.b,
                isEnabled:
                    false
            )
        ]

        try RemappingRulesValidator()
            .validate(
                rules
            )
    }

    func testValidatorRejectsDuplicateSourceAfterDisabledRuleIsReenabled() {
        let rules = [
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w
            ),
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.b
            )
        ]

        assertValidationError(
            .duplicateSourceKey(
                KeyCode.v
            ),
            rules:
                rules
        )
    }

    func testValidatorAllowsExactAndPreserveOverlapWhenPreserveRuleIsDisabled()
        throws
    {
        let commandV =
            combination(
                KeyCode.v,
                modifiers:
                    [.command]
            )

        let rules = [
            RemapRule(
                source:
                    commandV,
                destination:
                    combination(
                        KeyCode.b
                    ),
                matchingMode:
                    .exact
            ),
            preserveRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isEnabled:
                    false
            )
        ]

        try RemappingRulesValidator()
            .validate(
                rules
            )
    }

    func testValidatorIgnoresDisabledReverseDirectionConflict()
        throws
    {
        let rules = [
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isEnabled:
                    false,
                isBidirectional:
                    true
            ),
            exactRule(
                source:
                    KeyCode.w,
                destination:
                    KeyCode.b
            )
        ]

        try RemappingRulesValidator()
            .validate(
                rules
            )
    }

    func testValidatorIgnoresDisabledRuleExceptionsDuringConflictDetection()
        throws
    {
        let commandV =
            combination(
                KeyCode.v,
                modifiers:
                    [.command]
            )

        let rules = [
            RemapRule(
                source:
                    commandV,
                destination:
                    combination(
                        KeyCode.b
                    ),
                matchingMode:
                    .exact
            ),
            RemapRule(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source:
                            commandV,
                        action:
                            .passThrough,
                        isEnabled:
                            true
                    )
                ],
                isEnabled:
                    false,
                isBidirectional:
                    true
            )
        ]

        try RemappingRulesValidator()
            .validate(
                rules
            )
    }

    func testValidatorStillRejectsIdentityRuleWhenDisabled() {
        let rule =
            exactRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.v,
                isEnabled:
                    false
            )

        assertValidationError(
            .identicalSourceAndDestination(
                KeyCode.v
            ),
            rules:
                [
                    rule
                ]
        )
    }

    func testValidatorStillRejectsMirroredIdentityExceptionWhenDisabled() {
        let commandV =
            combination(
                KeyCode.v,
                modifiers:
                    [.command]
            )

        let commandW =
            combination(
                KeyCode.w,
                modifiers:
                    [.command]
            )

        let rule =
            RemapRule(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .preserveModifiers,
                overrides: [
                    RemapOverride(
                        source:
                            commandV,
                        action:
                            .replaceWith(
                                commandW
                            )
                    )
                ],
                isEnabled:
                    false,
                isBidirectional:
                    true
            )

        assertValidationError(
            .identicalSourceAndDestinationCombination(
                commandW
            ),
            rules:
                [
                    rule
                ]
        )
    }

    func testLiveAssessmentIgnoresDisabledRuleConflict() {
        let enabledItem =
            editorItem(
                from:
                    exactRule(
                        source:
                            KeyCode.v,
                        destination:
                            KeyCode.w
                    )
            )

        let disabledItem =
            editorItem(
                from:
                    exactRule(
                        source:
                            KeyCode.v,
                        destination:
                            KeyCode.b,
                        isEnabled:
                            false
                    )
            )

        let assessment =
            RemappingRulesValidationAssessment(
                items: [
                    enabledItem,
                    disabledItem
                ]
            )

        XCTAssertFalse(
            assessment.hasIssues
        )

        XCTAssertTrue(
            assessment.invalidItemIDs.isEmpty
        )
    }

    func testLiveAssessmentStillMarksDisabledIdentityRule() {
        let item =
            editorItem(
                from:
                    exactRule(
                        source:
                            KeyCode.v,
                        destination:
                            KeyCode.v,
                        isEnabled:
                            false
                    )
            )

        let assessment =
            RemappingRulesValidationAssessment(
                items:
                    [
                        item
                    ]
            )

        XCTAssertEqual(
            assessment.issues(
                forRuleID:
                    item.id
            ),
            [
                .identicalSourceAndDestination
            ]
        )
    }

    func testLiveAssessmentStillMarksIncompleteDisabledItem() {
        var item =
            RemappingRuleEditorItem()

        item.setEnabled(
            false
        )

        let assessment =
            RemappingRulesValidationAssessment(
                items:
                    [
                        item
                    ]
            )

        XCTAssertEqual(
            assessment.issues(
                forRuleID:
                    item.id
            ),
            [
                .incompleteRule
            ]
        )
    }

    private func exactRule(
        source: CGKeyCode,
        destination: CGKeyCode,
        isEnabled: Bool = true,
        isBidirectional: Bool = false
    ) -> RemapRule {
        RemapRule(
            source:
                combination(
                    source
                ),
            destination:
                combination(
                    destination
                ),
            matchingMode:
                .exact,
            isEnabled:
                isEnabled,
            isBidirectional:
                isBidirectional
        )
    }

    private func preserveRule(
        source: CGKeyCode,
        destination: CGKeyCode,
        isEnabled: Bool = true,
        isBidirectional: Bool = false
    ) -> RemapRule {
        RemapRule(
            source:
                combination(
                    source
                ),
            destination:
                combination(
                    destination
                ),
            matchingMode:
                .preserveModifiers,
            isEnabled:
                isEnabled,
            isBidirectional:
                isBidirectional
        )
    }

    private func editorItem(
        from rule: RemapRule
    ) -> RemappingRuleEditorItem {
        RemappingRuleEditorItem(
            rule:
                rule
        )
    }

    private func assertValidationError(
        _ expectedError:
            RemappingRulesValidationError,
        rules:
            [RemapRule],
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertThrowsError(
            try RemappingRulesValidator()
                .validate(
                    rules
                ),
            file:
                file,
            line:
                line
        ) {
            error in

            XCTAssertEqual(
                error as?
                    RemappingRulesValidationError,
                expectedError,
                file:
                    file,
                line:
                    line
            )
        }
    }

    private func assertDuplicateSourceIssue(
        for item:
            RemappingRuleEditorItem,
        in assessment:
            RemappingRulesValidationAssessment,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            assessment.affectsRule(
                id:
                    item.id
            ),
            file:
                file,
            line:
                line
        )

        XCTAssertTrue(
            assessment.issues(
                forRuleID:
                    item.id
            )
            .contains(
                .duplicateSource
            ),
            file:
                file,
            line:
                line
        )
    }

    private func combination(
        _ keyCode: CGKeyCode,
        modifiers: KeyModifiers = []
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers:
                modifiers
        )
    }
}
