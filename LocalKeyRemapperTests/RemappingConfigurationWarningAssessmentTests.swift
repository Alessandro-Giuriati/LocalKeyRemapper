//
//  RemappingConfigurationWarningAssessmentTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/24/26.
//

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class RemappingConfigurationWarningAssessmentTests:
    XCTestCase
{
    func testSafeItemsProduceNoWarning() {
        let item =
            makeItem(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    )
            )

        let assessment =
            RemappingConfigurationWarningAssessment(
                items: [
                    item
                ]
            )

        XCTAssertFalse(
            assessment.hasWarning
        )

        XCTAssertNil(
            assessment.warning
        )

        XCTAssertTrue(
            assessment.affectedRuleIDs.isEmpty
        )

        XCTAssertTrue(
            assessment
                .affectedExceptionIndexes(
                    forRuleID:
                        item.id
                )
                .isEmpty
        )
    }

    func testRuleEndpointWarningAssociatesParentRule() {
        let item =
            makeItem(
                source:
                    fnFunctionKeyCombination(
                        kVK_F1
                    ),
                destination:
                    combination(
                        KeyCode.w
                    )
            )

        let assessment =
            RemappingConfigurationWarningAssessment(
                items: [
                    item
                ]
            )

        XCTAssertTrue(
            assessment.hasWarning
        )

        XCTAssertEqual(
            assessment.warning,
            .fnWithFunctionKey
        )

        XCTAssertEqual(
            assessment.affectedRuleIDs,
            Set(
                [
                    item.id
                ]
            )
        )

        XCTAssertTrue(
            assessment
                .affectedExceptionIndexes(
                    forRuleID:
                        item.id
                )
                .isEmpty
        )
    }

    func testStoredExceptionWarningAssociatesParentAndExactIndex() {
        let safeOverride =
            RemapOverride(
                source:
                    combination(
                        CGKeyCode(
                            kVK_F1
                        ),
                        modifiers: [
                            .command
                        ]
                    ),
                action:
                    .passThrough
            )

        let warningOverride =
            RemapOverride(
                source:
                    fnFunctionKeyCombination(
                        kVK_F1
                    ),
                action:
                    .passThrough
            )

        let item =
            makeItem(
                source:
                    combination(
                        CGKeyCode(
                            kVK_F1
                        )
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .preserveModifiers,
                overrides: [
                    safeOverride,
                    warningOverride
                ]
            )

        let assessment =
            RemappingConfigurationWarningAssessment(
                items: [
                    item
                ]
            )

        XCTAssertEqual(
            assessment.warning,
            .fnWithFunctionKey
        )

        XCTAssertTrue(
            assessment.affectsRule(
                id:
                    item.id
            )
        )

        XCTAssertEqual(
            assessment
                .affectedExceptionIndexes(
                    forRuleID:
                        item.id
                ),
            Set(
                [
                    1
                ]
            )
        )
    }

    func testDisabledStoredExceptionStillProducesWarning() {
        let disabledWarningOverride =
            RemapOverride(
                source:
                    fnFunctionKeyCombination(
                        kVK_F2
                    ),
                action:
                    .passThrough,
                isEnabled:
                    false
            )

        let item =
            makeItem(
                source:
                    combination(
                        CGKeyCode(
                            kVK_F2
                        )
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .preserveModifiers,
                overrides: [
                    disabledWarningOverride
                ]
            )

        let assessment =
            RemappingConfigurationWarningAssessment(
                items: [
                    item
                ]
            )

        XCTAssertEqual(
            assessment.warning,
            .fnWithFunctionKey
        )

        XCTAssertEqual(
            assessment
                .affectedExceptionIndexes(
                    forRuleID:
                        item.id
                ),
            Set(
                [
                    0
                ]
            )
        )
    }

    func testStoredExceptionInExactModeStillProducesWarning() {
        let warningOverride =
            RemapOverride(
                source:
                    fnFunctionKeyCombination(
                        kVK_F3
                    ),
                action:
                    .replaceWith(
                        combination(
                            KeyCode.w
                        )
                    )
            )

        let item =
            makeItem(
                source:
                    combination(
                        CGKeyCode(
                            kVK_F3
                        )
                    ),
                destination:
                    combination(
                        KeyCode.w
                    ),
                matchingMode:
                    .exact,
                overrides: [
                    warningOverride
                ]
            )

        let assessment =
            RemappingConfigurationWarningAssessment(
                items: [
                    item
                ]
            )

        XCTAssertEqual(
            assessment.warning,
            .fnWithFunctionKey
        )

        XCTAssertTrue(
            assessment.affectsRule(
                id:
                    item.id
            )
        )

        XCTAssertEqual(
            assessment
                .affectedExceptionIndexes(
                    forRuleID:
                        item.id
                ),
            Set(
                [
                    0
                ]
            )
        )
    }

    func testWarningAssessmentUsesCompleteItemsWhenWarningRuleIsFilteredOut() {
        let visibleSafeItem =
            makeItem(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.w
                    )
            )

        let hiddenWarningItem =
            makeItem(
                source:
                    fnFunctionKeyCombination(
                        kVK_F4
                    ),
                destination:
                    combination(
                        KeyCode.b
                    )
            )

        let allItems = [
            visibleSafeItem,
            hiddenWarningItem
        ]

        let presentationModel =
            RemappingRulesPresentationModel()

        presentationModel.setSourceFilter(
            combination(
                KeyCode.v
            )
        )

        let visibleItems =
            presentationModel.visibleItems(
                from:
                    allItems
            )

        XCTAssertEqual(
            visibleItems.map(
                \.id
            ),
            [
                visibleSafeItem.id
            ]
        )

        let assessment =
            RemappingConfigurationWarningAssessment(
                items:
                    allItems
            )

        XCTAssertEqual(
            assessment.warning,
            .fnWithFunctionKey
        )

        XCTAssertTrue(
            assessment.affectsRule(
                id:
                    hiddenWarningItem.id
            )
        )

        XCTAssertFalse(
            assessment.affectsRule(
                id:
                    visibleSafeItem.id
            )
        )
    }

    func testWarningOnlyConfigurationRemainsValidationValid() {
        let item =
            makeItem(
                source:
                    fnFunctionKeyCombination(
                        kVK_F5
                    ),
                destination:
                    combination(
                        KeyCode.w
                    )
            )

        let warningAssessment =
            RemappingConfigurationWarningAssessment(
                items: [
                    item
                ]
            )

        let validationAssessment =
            RemappingRulesValidationAssessment(
                items: [
                    item
                ]
            )

        XCTAssertTrue(
            warningAssessment.hasWarning
        )

        XCTAssertFalse(
            validationAssessment.hasIssues
        )

        XCTAssertNil(
            validationAssessment.primaryIssue
        )

        XCTAssertNotNil(
            item.rule
        )
    }

    func testAssessmentDoesNotModifyEditorSessionState() {
        let session =
            RemappingRuleEditorSession()

        session.initialize(
            with: [
                RemapRule(
                    source:
                        fnFunctionKeyCombination(
                            kVK_F6
                        ),
                    destination:
                        combination(
                            KeyCode.w
                        ),
                    matchingMode:
                        .exact
                )
            ]
        )

        let originalItems =
            session.items

        let originalSavedRules =
            session.savedRules

        let originalHistoryEntryCount =
            session.historyEntryCount

        let originalCanUndo =
            session.canUndo

        let originalCanRedo =
            session.canRedo

        let originalDirtyState =
            session.hasUnsavedChanges

        let assessment =
            RemappingConfigurationWarningAssessment(
                items:
                    session.items
            )

        XCTAssertTrue(
            assessment.hasWarning
        )

        XCTAssertEqual(
            session.items,
            originalItems
        )

        XCTAssertEqual(
            session.savedRules,
            originalSavedRules
        )

        XCTAssertEqual(
            session.historyEntryCount,
            originalHistoryEntryCount
        )

        XCTAssertEqual(
            session.canUndo,
            originalCanUndo
        )

        XCTAssertEqual(
            session.canRedo,
            originalCanRedo
        )

        XCTAssertEqual(
            session.hasUnsavedChanges,
            originalDirtyState
        )
    }

    private func makeItem(
        source:
            KeyCombination?,
        destination:
            KeyCombination?,
        matchingMode:
            RemapMatchingMode = .exact,
        overrides:
            [RemapOverride] = []
    ) -> RemappingRuleEditorItem {
        RemappingRuleEditorItem(
            sourceCombination:
                source,
            destinationCombination:
                destination,
            matchingMode:
                matchingMode,
            overrides:
                overrides
        )
    }

    private func fnFunctionKeyCombination(
        _ carbonKeyCode:
            Int
    ) -> KeyCombination {
        combination(
            CGKeyCode(
                carbonKeyCode
            ),
            modifiers: [
                .fn
            ]
        )
    }

    private func combination(
        _ keyCode:
            CGKeyCode,
        modifiers:
            KeyModifiers = []
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers:
                modifiers
        )
    }
}
