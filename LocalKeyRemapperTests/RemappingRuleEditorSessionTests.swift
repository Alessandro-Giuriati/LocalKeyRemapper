//
//  RemappingRuleEditorSessionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/20/26.
//

import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class RemappingRuleEditorSessionTests:
    XCTestCase
{
    func testUndoingAndRedoingInsertion() {
        let session = makeEmptySession()
        let insertedID = session.insertEmptyItem()

        XCTAssertEqual(
            session.items.map(\.id),
            [insertedID]
        )
        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertTrue(session.items.isEmpty)
        XCTAssertTrue(session.canRedo)

        session.redo()

        XCTAssertEqual(
            session.items.map(\.id),
            [insertedID]
        )
    }

    func testUndoingAndRedoingRemovalRestoresOriginalPosition() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(
                    source: KeyCode.v,
                    destination: KeyCode.w
                ),
                makeRule(
                    source: KeyCode.b,
                    destination: KeyCode.j
                ),
                makeRule(
                    source: KeyCode.n,
                    destination: KeyCode.v
                )
            ]
        )

        let originalIDs = session.items.map(\.id)
        let removedID = originalIDs[1]

        session.removeItem(
            id: removedID
        )

        XCTAssertEqual(
            session.items.map(\.id),
            [
                originalIDs[0],
                originalIDs[2]
            ]
        )

        session.undo()

        XCTAssertEqual(
            session.items.map(\.id),
            originalIDs
        )

        session.redo()

        XCTAssertEqual(
            session.items.map(\.id),
            [
                originalIDs[0],
                originalIDs[2]
            ]
        )
    }

    func testUndoingRuleModificationRestoresCompletePreviousItem() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(
                    source: KeyCode.v,
                    destination: KeyCode.w
                )
            ]
        )

        let originalItem = session.items[0]
        var modifiedItem = originalItem
        modifiedItem.matchingMode = .preserveModifiers
        modifiedItem.sourceCombination = KeyCombination(
            keyCode: KeyCode.v
        )
        modifiedItem.destinationCombination = KeyCombination(
            keyCode: KeyCode.b
        )
        modifiedItem.overrides = [
            RemapOverride(
                source: KeyCombination(
                    keyCode: KeyCode.v,
                    modifiers: [.command]
                ),
                action: .passThrough
            )
        ]

        session.updateItem(modifiedItem)

        XCTAssertEqual(
            session.items[0],
            modifiedItem
        )

        session.undo()

        XCTAssertEqual(
            session.items[0],
            originalItem
        )

        session.redo()

        XCTAssertEqual(
            session.items[0],
            modifiedItem
        )
    }

    func testUndoAndRedoRestoresOverrideEnabledState() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRuleWithOverrides()
            ]
        )

        var disabledItem = session.items[0]
        disabledItem.overrides[0] = RemapOverride(
            source: disabledItem.overrides[0].source,
            action: disabledItem.overrides[0].action,
            isEnabled: false
        )

        session.updateItem(disabledItem)

        XCTAssertFalse(
            session.items[0].overrides[0].isEnabled
        )

        session.undo()

        XCTAssertTrue(
            session.items[0].overrides[0].isEnabled
        )

        session.redo()

        XCTAssertFalse(
            session.items[0].overrides[0].isEnabled
        )
    }

    func testUndoAndRedoModeChangePreservesOverrides() {
        let session = RemappingRuleEditorSession()
        let originalRule = makeRuleWithOverrides()

        session.initialize(
            with: [originalRule]
        )

        var exactItem = session.items[0]
        exactItem.matchingMode = .exact

        session.updateItem(exactItem)

        XCTAssertEqual(
            session.items[0].matchingMode,
            .exact
        )
        XCTAssertEqual(
            session.items[0].overrides,
            originalRule.overrides
        )

        session.undo()

        XCTAssertEqual(
            session.items[0].matchingMode,
            .preserveModifiers
        )
        XCTAssertEqual(
            session.items[0].overrides,
            originalRule.overrides
        )

        session.redo()

        XCTAssertEqual(
            session.items[0].matchingMode,
            .exact
        )
        XCTAssertEqual(
            session.items[0].overrides,
            originalRule.overrides
        )
    }

    func testUndoAndRedoPreservesOverrideOrder() {
        let session = RemappingRuleEditorSession()
        let originalRule = makeRuleWithOverrides()

        session.initialize(
            with: [originalRule]
        )

        var reorderedItem = session.items[0]
        reorderedItem.overrides.reverse()

        session.updateItem(reorderedItem)

        XCTAssertEqual(
            session.items[0].overrides,
            Array(originalRule.overrides.reversed())
        )

        session.undo()

        XCTAssertEqual(
            session.items[0].overrides,
            originalRule.overrides
        )

        session.redo()

        XCTAssertEqual(
            session.items[0].overrides,
            Array(originalRule.overrides.reversed())
        )
    }

    func testUndoAndRedoPreservesOverrideActions() {
        let session = RemappingRuleEditorSession()
        let originalRule = makeRuleWithOverrides()

        session.initialize(
            with: [originalRule]
        )

        var modifiedItem = session.items[0]
        modifiedItem.overrides[0] = RemapOverride(
            source: modifiedItem.overrides[0].source,
            action: .replaceWith(
                KeyCombination(
                    keyCode: KeyCode.b,
                    modifiers: [.option]
                )
            ),
            isEnabled: modifiedItem.overrides[0].isEnabled
        )
        modifiedItem.overrides[1] = RemapOverride(
            source: modifiedItem.overrides[1].source,
            action: .passThrough,
            isEnabled: modifiedItem.overrides[1].isEnabled
        )

        session.updateItem(modifiedItem)

        XCTAssertEqual(
            session.items[0].overrides,
            modifiedItem.overrides
        )

        session.undo()

        XCTAssertEqual(
            session.items[0].overrides,
            originalRule.overrides
        )

        session.redo()

        XCTAssertEqual(
            session.items[0].overrides,
            modifiedItem.overrides
        )
    }

    func testUndoingEntireRuleRemovalRestoresAllOverrides() {
        let session = RemappingRuleEditorSession()
        let originalRule = makeRuleWithOverrides()

        session.initialize(
            with: [originalRule]
        )

        let originalItem = session.items[0]

        session.removeItem(
            id: originalItem.id
        )

        XCTAssertTrue(session.items.isEmpty)

        session.undo()

        XCTAssertEqual(
            session.items,
            [originalItem]
        )
        XCTAssertEqual(
            session.items[0].overrides,
            originalRule.overrides
        )

        session.redo()

        XCTAssertTrue(session.items.isEmpty)
    }

    func testIncompleteRowsAreRestored() {
        let session = makeEmptySession()
        let itemID = session.insertEmptyItem()

        var incompleteItem = session.items[0]
        incompleteItem.sourceCombination = KeyCombination(
            keyCode: KeyCode.v
        )
        session.updateItem(incompleteItem)
        session.removeItem(id: itemID)

        session.undo()

        XCTAssertEqual(
            session.items.count,
            1
        )
        XCTAssertEqual(
            session.items[0].sourceCombination,
            incompleteItem.sourceCombination
        )
        XCTAssertNil(
            session.items[0].destinationCombination
        )
    }

    func testNewEditClearsRedo() {
        let session = makeEmptySession()

        _ = session.insertEmptyItem()
        session.undo()

        XCTAssertTrue(session.canRedo)

        _ = session.insertEmptyItem()

        XCTAssertFalse(session.canRedo)
    }

    func testSavingPreservesHistoryAndUndoMarksEditorUnsaved()
        throws
    {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(
                    source: KeyCode.v,
                    destination: KeyCode.w
                )
            ]
        )

        var modifiedItem = session.items[0]
        modifiedItem.destinationCombination = KeyCombination(
            keyCode: KeyCode.b
        )
        session.updateItem(modifiedItem)

        let savedRules = try XCTUnwrap(
            session.completeRules
        )
        session.markCurrentRulesAsSaved(
            savedRules
        )

        XCTAssertFalse(session.hasUnsavedChanges)
        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertTrue(session.hasUnsavedChanges)
        XCTAssertEqual(
            session.items[0]
                .destinationCombination?
                .keyCode,
            KeyCode.w
        )
    }

    func testUndoAndRedoRemainAvailableAfterSavingOverrideChanges()
        throws
    {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRuleWithOverrides()
            ]
        )

        var modifiedItem = session.items[0]
        modifiedItem.overrides[0] = RemapOverride(
            source: modifiedItem.overrides[0].source,
            action: modifiedItem.overrides[0].action,
            isEnabled: false
        )

        session.updateItem(modifiedItem)

        let savedRules = try XCTUnwrap(
            session.completeRules
        )
        session.markCurrentRulesAsSaved(
            savedRules
        )

        XCTAssertFalse(session.hasUnsavedChanges)
        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertTrue(
            session.items[0].overrides[0].isEnabled
        )
        XCTAssertTrue(session.hasUnsavedChanges)
        XCTAssertTrue(session.canRedo)

        session.redo()

        XCTAssertFalse(
            session.items[0].overrides[0].isEnabled
        )
        XCTAssertFalse(session.hasUnsavedChanges)
    }

    func testHistoryRemainsAvailableWhenWindowReferenceIsClosedAndReopened() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRuleWithOverrides()
            ]
        )

        var modifiedItem = session.items[0]
        modifiedItem.matchingMode = .exact
        modifiedItem.overrides[1] = RemapOverride(
            source: modifiedItem.overrides[1].source,
            action: modifiedItem.overrides[1].action,
            isEnabled: false
        )
        session.updateItem(modifiedItem)

        simulateClosingAndReopeningWindow(
            with: session
        )

        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertEqual(
            session.items[0].matchingMode,
            .preserveModifiers
        )
        XCTAssertTrue(
            session.items[0].overrides[1].isEnabled
        )
    }

    func testDiscardingUnsavedChangesIsItselfUndoable() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(
                    source: KeyCode.v,
                    destination: KeyCode.w
                )
            ]
        )

        _ = session.insertEmptyItem()
        let unsavedItems = session.items

        session.restoreSavedRules()

        XCTAssertEqual(
            session.items.count,
            1
        )
        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertEqual(
            session.items,
            unsavedItems
        )
    }

    func testSecondInitializationDoesNotReplaceSessionStateOrHistory() {
        let session = makeEmptySession()
        _ = session.insertEmptyItem()

        session.initialize(
            with: [
                makeRule(
                    source: KeyCode.v,
                    destination: KeyCode.w
                )
            ]
        )

        XCTAssertEqual(
            session.items.count,
            1
        )
        XCTAssertNil(session.items[0].rule)
        XCTAssertTrue(session.canUndo)
    }

    func testNewApplicationSessionStartsWithEmptyHistory() {
        let firstSession = makeEmptySession()
        _ = firstSession.insertEmptyItem()

        XCTAssertTrue(firstSession.canUndo)

        let newSession = makeEmptySession()

        XCTAssertFalse(newSession.canUndo)
        XCTAssertFalse(newSession.canRedo)
        XCTAssertEqual(
            newSession.historyEntryCount,
            0
        )
    }

    private func makeEmptySession()
        -> RemappingRuleEditorSession
    {
        let session = RemappingRuleEditorSession()
        session.initialize(with: [])
        return session
    }

    private func makeRule(
        source: CGKeyCode,
        destination: CGKeyCode
    ) -> RemapRule {
        RemapRule(
            source: KeyCombination(
                keyCode: source
            ),
            destination: KeyCombination(
                keyCode: destination
            )
        )
    }

    private func makeRuleWithOverrides()
        -> RemapRule
    {
        RemapRule(
            source: KeyCombination(
                keyCode: KeyCode.v
            ),
            destination: KeyCombination(
                keyCode: KeyCode.w
            ),
            matchingMode: .preserveModifiers,
            overrides: [
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.v,
                        modifiers: [.command]
                    ),
                    action: .passThrough,
                    isEnabled: true
                ),
                RemapOverride(
                    source: KeyCombination(
                        keyCode: KeyCode.v,
                        modifiers: [.shift]
                    ),
                    action: .replaceWith(
                        KeyCombination(
                            keyCode: KeyCode.j,
                            modifiers: [.option]
                        )
                    ),
                    isEnabled: true
                )
            ]
        )
    }

    private func simulateClosingAndReopeningWindow(
        with session: RemappingRuleEditorSession
    ) {
        _ = session.items
    }
}
