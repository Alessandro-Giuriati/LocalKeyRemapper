//
//  RemappingRulesPresentationModelTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class RemappingRulesPresentationModelTests:
    XCTestCase
{
    func testInitialStatePreservesOriginalItemOrder() {
        let model = RemappingRulesPresentationModel()
        let items = [
            makeItem(
                source: combination(KeyCode.v),
                destination: combination(KeyCode.w)
            ),
            makeItem(
                source: combination(KeyCode.b),
                destination: combination(KeyCode.j)
            ),
            makeItem(
                source: combination(KeyCode.n),
                destination: combination(KeyCode.r)
            )
        ]

        XCTAssertNil(model.sortDescriptor)
        XCTAssertFalse(model.hasActiveFilters)

        XCTAssertEqual(
            model.visibleItems(
                from: items
            ),
            items
        )
    }

    func testSelectingSameColumnReversesSortDirection() {
        let model = RemappingRulesPresentationModel()

        XCTAssertEqual(
            model.selectSortColumn(.source),
            RemappingRulesPresentationModel.SortDescriptor(
                column: .source,
                direction: .ascending
            )
        )

        XCTAssertEqual(
            model.selectSortColumn(.source),
            RemappingRulesPresentationModel.SortDescriptor(
                column: .source,
                direction: .descending
            )
        )

        XCTAssertEqual(
            model.selectSortColumn(.source),
            RemappingRulesPresentationModel.SortDescriptor(
                column: .source,
                direction: .ascending
            )
        )
    }

    func testSelectingDifferentColumnStartsAscending() {
        let model = RemappingRulesPresentationModel()

        _ = model.selectSortColumn(.source)
        _ = model.selectSortColumn(.source)

        XCTAssertEqual(
            model.sortDescriptor?.direction,
            .descending
        )

        _ = model.selectSortColumn(.destination)

        XCTAssertEqual(
            model.sortDescriptor,
            RemappingRulesPresentationModel.SortDescriptor(
                column: .destination,
                direction: .ascending
            )
        )
    }

    func testSourceSortingUsesLogicalKeyOrderAndModifiers() {
        let model = RemappingRulesPresentationModel()

        let f10 =
            makeItem(
                source:
                    combination(
                        CGKeyCode(kVK_F10)
                    ),
                destination: combination(KeyCode.w)
            )

        let shiftedF2 =
            makeItem(
                source:
                    combination(
                        CGKeyCode(kVK_F2),
                        modifiers: [.shift]
                    ),
                destination: combination(KeyCode.w)
            )

        let incomplete =
            makeItem(
                source: nil,
                destination: combination(KeyCode.w)
            )

        let plainF2 =
            makeItem(
                source:
                    combination(
                        CGKeyCode(kVK_F2)
                    ),
                destination: combination(KeyCode.w)
            )

        let originalItems = [
            f10,
            shiftedF2,
            incomplete,
            plainF2
        ]

        _ = model.selectSortColumn(.source)

        XCTAssertEqual(
            model.visibleItems(
                from: originalItems
            ).map(\.id),
            [
                plainF2.id,
                shiftedF2.id,
                f10.id,
                incomplete.id
            ]
        )

        _ = model.selectSortColumn(.source)

        XCTAssertEqual(
            model.visibleItems(
                from: originalItems
            ).map(\.id),
            [
                f10.id,
                shiftedF2.id,
                plainF2.id,
                incomplete.id
            ]
        )
    }

    func testDestinationSortingUsesDestinationOnly() {
        let model = RemappingRulesPresentationModel()

        let destinationF3 =
            makeItem(
                source: combination(KeyCode.b),
                destination:
                    combination(
                        CGKeyCode(kVK_F3)
                    )
            )

        let destinationF1 =
            makeItem(
                source: combination(KeyCode.v),
                destination:
                    combination(
                        CGKeyCode(kVK_F1)
                    )
            )

        let destinationF2 =
            makeItem(
                source: combination(KeyCode.n),
                destination:
                    combination(
                        CGKeyCode(kVK_F2)
                    )
            )

        _ = model.selectSortColumn(
            .destination
        )

        XCTAssertEqual(
            model.visibleItems(
                from: [
                    destinationF3,
                    destinationF1,
                    destinationF2
                ]
            ).map(\.id),
            [
                destinationF1.id,
                destinationF2.id,
                destinationF3.id
            ]
        )
    }

    func testModifierBehaviorSortingGroupsByBehaviorName() {
        let model = RemappingRulesPresentationModel()

        let preserveFirst =
            makeItem(
                source: combination(KeyCode.v),
                destination: combination(KeyCode.w),
                matchingMode: .preserveModifiers
            )

        let exact =
            makeItem(
                source: combination(KeyCode.b),
                destination: combination(KeyCode.j),
                matchingMode: .exact
            )

        let preserveSecond =
            makeItem(
                source: combination(KeyCode.n),
                destination: combination(KeyCode.r),
                matchingMode: .preserveModifiers
            )

        _ = model.selectSortColumn(
            .modifierBehavior
        )

        XCTAssertEqual(
            model.visibleItems(
                from: [
                    preserveFirst,
                    exact,
                    preserveSecond
                ]
            ).map(\.id),
            [
                exact.id,
                preserveFirst.id,
                preserveSecond.id
            ]
        )
    }

    func testExceptionSortingUsesStoredExceptionCount() {
        let model = RemappingRulesPresentationModel()

        let threeExceptions =
            makeItem(
                source: combination(KeyCode.v),
                destination: combination(KeyCode.w),
                exceptionCount: 3
            )

        let noExceptions =
            makeItem(
                source: combination(KeyCode.b),
                destination: combination(KeyCode.j)
            )

        let oneException =
            makeItem(
                source: combination(KeyCode.n),
                destination: combination(KeyCode.r),
                exceptionCount: 1
            )

        let originalItems = [
            threeExceptions,
            noExceptions,
            oneException
        ]

        _ = model.selectSortColumn(
            .exceptions
        )

        XCTAssertEqual(
            model.visibleItems(
                from: originalItems
            ).map(\.id),
            [
                noExceptions.id,
                oneException.id,
                threeExceptions.id
            ]
        )

        _ = model.selectSortColumn(
            .exceptions
        )

        XCTAssertEqual(
            model.visibleItems(
                from: originalItems
            ).map(\.id),
            [
                threeExceptions.id,
                oneException.id,
                noExceptions.id
            ]
        )
    }

    func testSourceFilterMatchesPhysicalKeyRegardlessOfModifiers() {
        let model = RemappingRulesPresentationModel()

        let plainV =
            makeItem(
                source: combination(KeyCode.v),
                destination: combination(KeyCode.w)
            )

        let commandV =
            makeItem(
                source:
                    combination(
                        KeyCode.v,
                        modifiers: [.command]
                    ),
                destination: combination(KeyCode.b)
            )

        let destinationOnlyV =
            makeItem(
                source: combination(KeyCode.b),
                destination: combination(KeyCode.v)
            )

        model.setSourceFilter(
            combination(
                KeyCode.v,
                modifiers: [.shift]
            )
        )

        XCTAssertEqual(
            model.visibleItems(
                from: [
                    plainV,
                    commandV,
                    destinationOnlyV
                ]
            ).map(\.id),
            [
                plainV.id,
                commandV.id
            ]
        )
    }

    func testDestinationFilterDoesNotInspectSource() {
        let model = RemappingRulesPresentationModel()

        let destinationW =
            makeItem(
                source: combination(KeyCode.v),
                destination: combination(KeyCode.w)
            )

        let commandDestinationW =
            makeItem(
                source: combination(KeyCode.b),
                destination:
                    combination(
                        KeyCode.w,
                        modifiers: [.command]
                    )
            )

        let sourceOnlyW =
            makeItem(
                source: combination(KeyCode.w),
                destination: combination(KeyCode.j)
            )

        model.setDestinationFilter(
            combination(
                KeyCode.w,
                modifiers: [.option]
            )
        )

        XCTAssertEqual(
            model.visibleItems(
                from: [
                    destinationW,
                    commandDestinationW,
                    sourceOnlyW
                ]
            ).map(\.id),
            [
                destinationW.id,
                commandDestinationW.id
            ]
        )
    }

    func testSourceAndDestinationFiltersUseAndCondition() {
        let model = RemappingRulesPresentationModel()

        let vToW =
            makeItem(
                source: combination(KeyCode.v),
                destination: combination(KeyCode.w)
            )

        let vToB =
            makeItem(
                source: combination(KeyCode.v),
                destination: combination(KeyCode.b)
            )

        let bToW =
            makeItem(
                source: combination(KeyCode.b),
                destination: combination(KeyCode.w)
            )

        let allItems = [
            vToW,
            vToB,
            bToW
        ]

        model.setSourceFilter(
            combination(KeyCode.v)
        )

        model.setDestinationFilter(
            combination(KeyCode.w)
        )

        XCTAssertEqual(
            model.visibleItems(
                from: allItems
            ).map(\.id),
            [vToW.id]
        )

        model.clearSourceFilter()

        XCTAssertEqual(
            model.visibleItems(
                from: allItems
            ).map(\.id),
            [
                vToW.id,
                bToW.id
            ]
        )

        model.clearDestinationFilter()

        XCTAssertEqual(
            model.visibleItems(
                from: allItems
            ),
            allItems
        )
    }

    func testSortingAndFilteringDoNotModifyEditorSessionState() {
        let session = RemappingRuleEditorSession()

        session.initialize(
            with: [
                RemapRule(
                    source: combination(KeyCode.v),
                    destination: combination(KeyCode.w),
                    matchingMode: .exact
                ),
                RemapRule(
                    source: combination(KeyCode.b),
                    destination: combination(KeyCode.j),
                    matchingMode: .preserveModifiers
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

        let model =
            RemappingRulesPresentationModel()

        _ = model.selectSortColumn(.source)
        _ = model.selectSortColumn(.source)

        model.setSourceFilter(
            combination(KeyCode.v)
        )

        _ = model.visibleItems(
            from: session.items
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
        source: KeyCombination?,
        destination: KeyCombination?,
        matchingMode: RemapMatchingMode = .exact,
        exceptionCount: Int = 0
    ) -> RemappingRuleEditorItem {
        let overrideSourceKeyCode =
            source?.keyCode
            ?? KeyCode.v

        let storedOverride =
            RemapOverride(
                source:
                    KeyCombination(
                        keyCode:
                            overrideSourceKeyCode,
                        modifiers: [.command]
                    ),
                action: .passThrough
            )

        return RemappingRuleEditorItem(
            sourceCombination: source,
            destinationCombination: destination,
            matchingMode: matchingMode,
            overrides:
                Array(
                    repeating:
                        storedOverride,
                    count:
                        exceptionCount
                )
        )
    }

    private func combination(
        _ keyCode: CGKeyCode,
        modifiers: KeyModifiers = []
    ) -> KeyCombination {
        KeyCombination(
            keyCode: keyCode,
            modifiers: modifiers
        )
    }
}
