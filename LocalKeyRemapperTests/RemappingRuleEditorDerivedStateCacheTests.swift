//
//  RemappingRuleEditorDerivedStateCacheTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 8/3/26.
//

import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class RemappingRuleEditorDerivedStateCacheTests:
    XCTestCase
{
    func testDerivedStateRefreshesAfterContentSaveUndoAndRedo()
        throws
    {
        let session =
            RemappingRuleEditorSession()

        session.initialize(
            with: [
                makeRule(
                    source:
                        KeyCode.v,
                    destination:
                        KeyCode.w,
                    isEnabled:
                        true,
                    isBidirectional:
                        true
                ),
                makeRule(
                    source:
                        KeyCode.b,
                    destination:
                        KeyCode.j,
                    isEnabled:
                        false,
                    isBidirectional:
                        false
                )
            ]
        )

        XCTAssertEqual(
            session.contentRevision,
            1
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .mixed
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        XCTAssertEqual(
            session.completeRules?.count,
            2
        )

        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        var updatedItem =
            session.items[1]

        updatedItem.setEnabled(
            true
        )

        updatedItem.setBidirectional(
            true
        )

        session.updateItem(
            updatedItem
        )

        XCTAssertEqual(
            session.contentRevision,
            2
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .enabled
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .enabled
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )

        let savedRules =
            try XCTUnwrap(
                session.completeRules
            )

        session.markCurrentRulesAsSaved(
            savedRules
        )

        XCTAssertEqual(
            session.contentRevision,
            2
        )

        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        session.undo()

        XCTAssertEqual(
            session.contentRevision,
            3
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .mixed
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )

        session.redo()

        XCTAssertEqual(
            session.contentRevision,
            4
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .enabled
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .enabled
        )

        XCTAssertFalse(
            session.hasUnsavedChanges
        )
    }

    func testIncompleteRowsInvalidateAndRestoreCompleteRulesCache() {
        let session =
            RemappingRuleEditorSession()

        session.initialize(
            with: [
                makeRule(
                    source:
                        KeyCode.v,
                    destination:
                        KeyCode.w
                )
            ]
        )

        XCTAssertEqual(
            session.completeRules?.count,
            1
        )

        _ = session.insertEmptyItem()

        XCTAssertNil(
            session.completeRules
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )

        session.undo()

        XCTAssertEqual(
            session.completeRules?.count,
            1
        )

        XCTAssertFalse(
            session.hasUnsavedChanges
        )

        session.redo()

        XCTAssertNil(
            session.completeRules
        )

        XCTAssertTrue(
            session.hasUnsavedChanges
        )
    }

    func testNoOpOperationsDoNotAdvanceContentRevision() {
        let session =
            RemappingRuleEditorSession()

        let originalRule =
            makeRule(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isEnabled:
                    true,
                isBidirectional:
                    false
            )

        session.initialize(
            with: [
                originalRule
            ]
        )

        let originalRevision =
            session.contentRevision

        session.updateItem(
            session.items[0]
        )

        session.setEnabledForAll(
            true
        )

        session.setBidirectionalForAll(
            false
        )

        session.removeItem(
            id:
                UUID()
        )

        session.initialize(
            with: []
        )

        session.markCurrentRulesAsSaved(
            [
                originalRule
            ]
        )

        XCTAssertEqual(
            session.contentRevision,
            originalRevision
        )
    }

    private func makeRule(
        source:
            CGKeyCode,
        destination:
            CGKeyCode,
        isEnabled:
            Bool = true,
        isBidirectional:
            Bool = false
    ) -> RemapRule {
        RemapRule(
            source:
                KeyCombination(
                    keyCode:
                        source
                ),
            destination:
                KeyCombination(
                    keyCode:
                        destination
                ),
            isEnabled:
                isEnabled,
            isBidirectional:
                isBidirectional
        )
    }
}
