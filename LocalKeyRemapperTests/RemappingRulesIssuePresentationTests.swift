//  RemappingRulesIssuePresentationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/24/26.
//

import Carbon.HIToolbox
import CoreGraphics
import Foundation
import XCTest
@testable import LocalKeyRemapper

final class RemappingRulesIssuePresentationTests:
    XCTestCase
{
    func testValidationIssueFilterShowsOnlyValidationRules() {
        let model =
            RemappingRulesPresentationModel()

        let validationItem =
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

        let warningItem =
            makeItem(
                source:
                    combination(
                        KeyCode.b
                    ),
                destination:
                    combination(
                        KeyCode.j
                    )
            )

        let safeItem =
            makeItem(
                source:
                    combination(
                        KeyCode.n
                    ),
                destination:
                    combination(
                        KeyCode.r
                    )
            )

        model.toggleValidationIssueFilter()

        let visibleItems =
            model.visibleItems(
                from: [
                    validationItem,
                    warningItem,
                    safeItem
                ],
                validationIssueItemIDs:
                    Set(
                        [
                            validationItem.id
                        ]
                    ),
                configurationWarningItemIDs:
                    Set(
                        [
                            warningItem.id
                        ]
                    )
            )

        XCTAssertEqual(
            visibleItems.map(
                \.id
            ),
            [
                validationItem.id
            ]
        )
    }

    func testConfigurationWarningFilterShowsOnlyWarningRules() {
        let model =
            RemappingRulesPresentationModel()

        let validationItem =
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

        let warningItem =
            makeItem(
                source:
                    combination(
                        KeyCode.b
                    ),
                destination:
                    combination(
                        KeyCode.j
                    )
            )

        let safeItem =
            makeItem(
                source:
                    combination(
                        KeyCode.n
                    ),
                destination:
                    combination(
                        KeyCode.r
                    )
            )

        model.toggleConfigurationWarningFilter()

        let visibleItems =
            model.visibleItems(
                from: [
                    validationItem,
                    warningItem,
                    safeItem
                ],
                validationIssueItemIDs:
                    Set(
                        [
                            validationItem.id
                        ]
                    ),
                configurationWarningItemIDs:
                    Set(
                        [
                            warningItem.id
                        ]
                    )
            )

        XCTAssertEqual(
            visibleItems.map(
                \.id
            ),
            [
                warningItem.id
            ]
        )
    }

    func testCombinedIssueFiltersUseOrSemantics() {
        let model =
            RemappingRulesPresentationModel()

        let validationItem =
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

        let warningItem =
            makeItem(
                source:
                    combination(
                        KeyCode.b
                    ),
                destination:
                    combination(
                        KeyCode.j
                    )
            )

        let bothItem =
            makeItem(
                source:
                    combination(
                        KeyCode.n
                    ),
                destination:
                    combination(
                        KeyCode.r
                    )
            )

        let safeItem =
            makeItem(
                source:
                    combination(
                        CGKeyCode(
                            kVK_ANSI_M
                        )
                    ),
                destination:
                    combination(
                        CGKeyCode(
                            kVK_ANSI_K
                        )
                    )
            )

        model.toggleValidationIssueFilter()
        model.toggleConfigurationWarningFilter()

        let visibleItems =
            model.visibleItems(
                from: [
                    validationItem,
                    warningItem,
                    bothItem,
                    safeItem
                ],
                validationIssueItemIDs:
                    Set(
                        [
                            validationItem.id,
                            bothItem.id
                        ]
                    ),
                configurationWarningItemIDs:
                    Set(
                        [
                            warningItem.id,
                            bothItem.id
                        ]
                    )
            )

        XCTAssertEqual(
            visibleItems.map(
                \.id
            ),
            [
                validationItem.id,
                warningItem.id,
                bothItem.id
            ]
        )
    }

    func testKeyFiltersAndIssueFiltersUseAndSemantics() {
        let model =
            RemappingRulesPresentationModel()

        let matchingWarningItem =
            makeItem(
                source:
                    combination(
                        KeyCode.v,
                        modifiers: [
                            .command
                        ]
                    ),
                destination:
                    combination(
                        KeyCode.w
                    )
            )

        let matchingSafeItem =
            makeItem(
                source:
                    combination(
                        KeyCode.v
                    ),
                destination:
                    combination(
                        KeyCode.b
                    )
            )

        let otherWarningItem =
            makeItem(
                source:
                    combination(
                        KeyCode.n
                    ),
                destination:
                    combination(
                        KeyCode.w
                    )
            )

        model.setSourceFilter(
            combination(
                KeyCode.v
            )
        )

        model.toggleConfigurationWarningFilter()

        let visibleItems =
            model.visibleItems(
                from: [
                    matchingWarningItem,
                    matchingSafeItem,
                    otherWarningItem
                ],
                configurationWarningItemIDs:
                    Set(
                        [
                            matchingWarningItem.id,
                            otherWarningItem.id
                        ]
                    )
            )

        XCTAssertEqual(
            visibleItems.map(
                \.id
            ),
            [
                matchingWarningItem.id
            ]
        )
    }

    func testIssuesSortingUsesSeverityOrderAndReverses() {
        let model =
            RemappingRulesPresentationModel()

        let noIssueItem =
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

        let warningItem =
            makeItem(
                source:
                    combination(
                        KeyCode.b
                    ),
                destination:
                    combination(
                        KeyCode.j
                    )
            )

        let validationItem =
            makeItem(
                source:
                    combination(
                        KeyCode.n
                    ),
                destination:
                    combination(
                        KeyCode.r
                    )
            )

        let bothItem =
            makeItem(
                source:
                    combination(
                        CGKeyCode(
                            kVK_ANSI_M
                        )
                    ),
                destination:
                    combination(
                        CGKeyCode(
                            kVK_ANSI_K
                        )
                    )
            )

        let allItems = [
            bothItem,
            validationItem,
            warningItem,
            noIssueItem
        ]

        let validationIDs =
            Set(
                [
                    validationItem.id,
                    bothItem.id
                ]
            )

        let warningIDs =
            Set(
                [
                    warningItem.id,
                    bothItem.id
                ]
            )

        _ = model.selectSortColumn(
            .issues
        )

        XCTAssertEqual(
            model.visibleItems(
                from:
                    allItems,
                validationIssueItemIDs:
                    validationIDs,
                configurationWarningItemIDs:
                    warningIDs
            ).map(
                \.id
            ),
            [
                noIssueItem.id,
                warningItem.id,
                validationItem.id,
                bothItem.id
            ]
        )

        _ = model.selectSortColumn(
            .issues
        )

        XCTAssertEqual(
            model.visibleItems(
                from:
                    allItems,
                validationIssueItemIDs:
                    validationIDs,
                configurationWarningItemIDs:
                    warningIDs
            ).map(
                \.id
            ),
            [
                bothItem.id,
                validationItem.id,
                warningItem.id,
                noIssueItem.id
            ]
        )
    }

    func testClearAllFiltersAlsoClearsIssueFilters() {
        let model =
            RemappingRulesPresentationModel()

        model.setSourceFilter(
            combination(
                KeyCode.v
            )
        )

        model.setDestinationFilter(
            combination(
                KeyCode.w
            )
        )

        model.toggleValidationIssueFilter()
        model.toggleConfigurationWarningFilter()

        XCTAssertTrue(
            model.hasActiveFilters
        )

        model.clearAllFilters()

        XCTAssertFalse(
            model.hasActiveFilters
        )

        XCTAssertFalse(
            model.hasActiveIssueFilters
        )

        XCTAssertFalse(
            model.showsOnlyValidationIssues
        )

        XCTAssertFalse(
            model.showsOnlyConfigurationWarnings
        )

        XCTAssertNil(
            model.sourceFilterKeyCode
        )

        XCTAssertNil(
            model.destinationFilterKeyCode
        )
    }

    func testIssueSortingAndFilteringDoNotModifyEditorSessionState() {
        let session =
            RemappingRuleEditorSession()

        session.initialize(
            with: [
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
                        .exact
                ),
                RemapRule(
                    source:
                        combination(
                            KeyCode.b
                        ),
                    destination:
                        combination(
                            KeyCode.j
                        ),
                    matchingMode:
                        .preserveModifiers
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

        let firstItemID =
            session.items[
                0
            ].id

        let secondItemID =
            session.items[
                1
            ].id

        let model =
            RemappingRulesPresentationModel()

        model.toggleValidationIssueFilter()
        model.toggleConfigurationWarningFilter()

        _ = model.selectSortColumn(
            .issues
        )

        _ = model.visibleItems(
            from:
                session.items,
            validationIssueItemIDs:
                Set(
                    [
                        firstItemID
                    ]
                ),
            configurationWarningItemIDs:
                Set(
                    [
                        secondItemID
                    ]
                )
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
            KeyCombination?
    ) -> RemappingRuleEditorItem {
        RemappingRuleEditorItem(
            sourceCombination:
                source,
            destinationCombination:
                destination,
            matchingMode:
                .exact
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
