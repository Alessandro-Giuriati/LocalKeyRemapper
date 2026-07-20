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

        XCTAssertEqual(session.items.map(\.id), [insertedID])
        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertTrue(session.items.isEmpty)
        XCTAssertTrue(session.canRedo)

        session.redo()

        XCTAssertEqual(session.items.map(\.id), [insertedID])
    }

    func testUndoingAndRedoingRemovalRestoresOriginalPosition() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(source: KeyCode.v, destination: KeyCode.w),
                makeRule(source: KeyCode.b, destination: KeyCode.j),
                makeRule(source: KeyCode.n, destination: KeyCode.v)
            ]
        )

        let originalIDs = session.items.map(\.id)
        let removedID = originalIDs[1]

        session.removeItem(id: removedID)

        XCTAssertEqual(
            session.items.map(\.id),
            [originalIDs[0], originalIDs[2]]
        )

        session.undo()

        XCTAssertEqual(session.items.map(\.id), originalIDs)

        session.redo()

        XCTAssertEqual(
            session.items.map(\.id),
            [originalIDs[0], originalIDs[2]]
        )
    }

    func testUndoingRuleModificationRestoresCompletePreviousItem() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(source: KeyCode.v, destination: KeyCode.w)
            ]
        )

        let originalItem = session.items[0]
        var modifiedItem = originalItem
        modifiedItem.destinationCombination = KeyCombination(
            keyCode: KeyCode.b,
            modifiers: [.command]
        )
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
        XCTAssertEqual(session.items[0], modifiedItem)

        session.undo()
        XCTAssertEqual(session.items[0], originalItem)

        session.redo()
        XCTAssertEqual(session.items[0], modifiedItem)
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

        XCTAssertEqual(session.items.count, 1)
        XCTAssertEqual(
            session.items[0].sourceCombination,
            incompleteItem.sourceCombination
        )
        XCTAssertNil(session.items[0].destinationCombination)
    }

    func testNewEditClearsRedo() {
        let session = makeEmptySession()

        _ = session.insertEmptyItem()
        session.undo()
        XCTAssertTrue(session.canRedo)

        _ = session.insertEmptyItem()

        XCTAssertFalse(session.canRedo)
    }

    func testSavingPreservesHistoryAndUndoMarksEditorUnsaved() throws {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(source: KeyCode.v, destination: KeyCode.w)
            ]
        )

        var modifiedItem = session.items[0]
        modifiedItem.destinationCombination = KeyCombination(
            keyCode: KeyCode.b
        )
        session.updateItem(modifiedItem)

        let savedRules = try XCTUnwrap(session.completeRules)
        session.markCurrentRulesAsSaved(savedRules)

        XCTAssertFalse(session.hasUnsavedChanges)
        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertTrue(session.hasUnsavedChanges)
        XCTAssertEqual(
            session.items[0].destinationCombination?.keyCode,
            KeyCode.w
        )
    }

    func testHistoryRemainsAvailableWhenWindowReferenceIsClosedAndReopened() {
        let session = makeEmptySession()
        _ = session.insertEmptyItem()

        simulateClosingAndReopeningWindow(
            with: session
        )

        XCTAssertTrue(session.canUndo)
        session.undo()
        XCTAssertTrue(session.items.isEmpty)
    }

    func testDiscardingUnsavedChangesIsItselfUndoable() {
        let session = RemappingRuleEditorSession()
        session.initialize(
            with: [
                makeRule(source: KeyCode.v, destination: KeyCode.w)
            ]
        )

        _ = session.insertEmptyItem()
        let unsavedItems = session.items

        session.restoreSavedRules()

        XCTAssertEqual(session.items.count, 1)
        XCTAssertTrue(session.canUndo)

        session.undo()

        XCTAssertEqual(session.items, unsavedItems)
    }

    func testSecondInitializationDoesNotReplaceSessionStateOrHistory() {
        let session = makeEmptySession()
        _ = session.insertEmptyItem()

        session.initialize(
            with: [
                makeRule(source: KeyCode.v, destination: KeyCode.w)
            ]
        )

        XCTAssertEqual(session.items.count, 1)
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
        XCTAssertEqual(newSession.historyEntryCount, 0)
    }

    private func makeEmptySession() ->
        RemappingRuleEditorSession
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

    private func simulateClosingAndReopeningWindow(
        with session: RemappingRuleEditorSession
    ) {
        _ = session.items
    }
}
