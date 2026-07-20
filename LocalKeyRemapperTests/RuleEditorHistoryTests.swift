//
//  RuleEditorHistoryTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/20/26.
//

import XCTest
@testable import LocalKeyRemapper

final class RuleEditorHistoryTests:
    XCTestCase
{
    func testNewHistoryStartsEmpty() {
        let history = RuleEditorHistory()

        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.totalEntryCount, 0)
        XCTAssertEqual(history.totalEstimatedPayloadSize, 0)
    }

    func testRecordingNewActionClearsRedo() {
        let history = RuleEditorHistory()
        let firstAction = makeInsertAction(index: 0)
        let secondAction = makeInsertAction(index: 1)

        history.record(firstAction)
        XCTAssertEqual(history.takeUndoAction(), firstAction)
        XCTAssertTrue(history.canRedo)

        history.record(secondAction)

        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.totalEntryCount, 1)
        XCTAssertEqual(history.takeUndoAction(), secondAction)
    }

    func testUndoAndRedoEntriesShareTheEntryLimit() {
        let history = RuleEditorHistory(
            maximumEntryCount: 3,
            maximumEstimatedPayloadSize: .max
        )

        history.record(makeInsertAction(index: 0))
        history.record(makeInsertAction(index: 1))
        history.record(makeInsertAction(index: 2))

        _ = history.takeUndoAction()
        _ = history.takeUndoAction()

        XCTAssertEqual(history.undoEntryCount, 1)
        XCTAssertEqual(history.redoEntryCount, 2)
        XCTAssertEqual(history.totalEntryCount, 3)
    }

    func testOldestEntriesAreRemovedAfterFiveThousandEntries() {
        let history = RuleEditorHistory()

        for index in 0...5_000 {
            history.record(
                makeInsertAction(index: index)
            )
        }

        XCTAssertEqual(history.totalEntryCount, 5_000)

        for _ in 0..<5_000 {
            XCTAssertNotNil(history.takeUndoAction())
        }

        XCTAssertNil(history.takeUndoAction())
    }

    func testOldestEntriesAreRemovedAfterEstimatedByteLimit() {
        let action = makeInsertAction(index: 0)
        let twoActionLimit =
            action.estimatedPayloadSize * 2

        let history = RuleEditorHistory(
            maximumEntryCount: 100,
            maximumEstimatedPayloadSize: twoActionLimit
        )

        history.record(action)
        history.record(makeInsertAction(index: 1))
        history.record(makeInsertAction(index: 2))

        XCTAssertEqual(history.totalEntryCount, 2)
        XCTAssertLessThanOrEqual(
            history.totalEstimatedPayloadSize,
            twoActionLimit
        )
    }


    func testDefaultEstimatedPayloadLimitIsEnforced() {
        let history = RuleEditorHistory()
        let overrides = (0..<200).map { index in
            RemapOverride(
                source: KeyCombination(
                    keyCode: KeyCode.v,
                    modifiers: index.isMultiple(of: 2)
                        ? []
                        : [.command]
                ),
                action: .replaceWith(
                    KeyCombination(
                        keyCode: KeyCode.w
                    )
                )
            )
        }

        let before = RemappingRuleEditorItem(
            sourceCombination: KeyCombination(
                keyCode: KeyCode.v
            ),
            destinationCombination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: overrides
        )

        var after = before
        after.destinationCombination = KeyCombination(
            keyCode: KeyCode.b
        )

        for _ in 0..<200 {
            history.record(
                .update(
                    before: before,
                    after: after
                )
            )
        }

        XCTAssertLessThanOrEqual(
            history.totalEstimatedPayloadSize,
            RuleEditorHistory.defaultMaximumEstimatedPayloadSize
        )
        XCTAssertLessThan(history.totalEntryCount, 200)
    }

    func testClearRemovesUndoRedoAndPayload() {
        let history = RuleEditorHistory()

        history.record(makeInsertAction(index: 0))
        _ = history.takeUndoAction()
        history.clear()

        XCTAssertFalse(history.canUndo)
        XCTAssertFalse(history.canRedo)
        XCTAssertEqual(history.totalEntryCount, 0)
        XCTAssertEqual(history.totalEstimatedPayloadSize, 0)
    }

    private func makeInsertAction(
        index: Int
    ) -> RuleEditorAction {
        .insert(
            item: RemappingRuleEditorItem(),
            index: index
        )
    }
}
