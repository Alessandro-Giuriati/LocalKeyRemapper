//
//  BidirectionalRemappingModelTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/26/26.
//

import Carbon.HIToolbox
import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

final class BidirectionalRemappingModelTests:
    XCTestCase
{
    func testEncodingAndDecodingPreservesBidirectionalState()
        throws
    {
        let originalRule =
            makeRule(
                source: KeyCode.v,
                destination: KeyCode.w,
                isBidirectional: true
            )

        let data =
            try JSONEncoder()
                .encode(
                    originalRule
                )

        let decodedRule =
            try JSONDecoder()
                .decode(
                    RemapRule.self,
                    from: data
                )

        XCTAssertTrue(
            decodedRule.isBidirectional
        )

        XCTAssertEqual(
            decodedRule,
            originalRule
        )
    }

    func testDecodingLegacyRuleWithoutBidirectionalFieldDefaultsToFalse()
        throws
    {
        let currentRule =
            makeRule(
                source: KeyCode.v,
                destination: KeyCode.w,
                isBidirectional: false
            )

        let currentData =
            try JSONEncoder()
                .encode(
                    currentRule
                )

        var legacyObject =
            try XCTUnwrap(
                JSONSerialization
                    .jsonObject(
                        with: currentData
                    )
                    as? [String: Any]
            )

        legacyObject.removeValue(
            forKey:
                "isBidirectional"
        )

        let legacyData =
            try JSONSerialization
                .data(
                    withJSONObject:
                        legacyObject
                )

        let decodedRule =
            try JSONDecoder()
                .decode(
                    RemapRule.self,
                    from: legacyData
                )

        XCTAssertFalse(
            decodedRule.isBidirectional
        )
    }

    func testEditorItemPreservesBidirectionalStateWhenConvertingToAndFromRule()
        throws
    {
        let originalRule =
            makeRule(
                source: KeyCode.v,
                destination: KeyCode.w,
                isBidirectional: true
            )

        var editorItem =
            RemappingRuleEditorItem(
                rule:
                    originalRule
            )

        XCTAssertTrue(
            editorItem.isBidirectional
        )

        XCTAssertTrue(
            try XCTUnwrap(
                editorItem.rule
            )
            .isBidirectional
        )

        editorItem.setBidirectional(
            false
        )

        XCTAssertFalse(
            editorItem.isBidirectional
        )

        XCTAssertFalse(
            try XCTUnwrap(
                editorItem.rule
            )
            .isBidirectional
        )
    }

    func testEncodingAndDecodingPreservesActivationState()
        throws
    {
        let originalRule =
            RemapRule(
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
                    .exact,
                isEnabled:
                    false,
                isBidirectional:
                    true
            )

        let data =
            try JSONEncoder()
                .encode(
                    originalRule
                )

        let decodedRule =
            try JSONDecoder()
                .decode(
                    RemapRule.self,
                    from:
                        data
                )

        XCTAssertFalse(
            decodedRule.isEnabled
        )

        XCTAssertTrue(
            decodedRule.isBidirectional
        )

        XCTAssertEqual(
            decodedRule,
            originalRule
        )
    }

    func testDecodingLegacyRuleWithoutActivationFieldDefaultsToEnabled()
        throws
    {
        let currentRule =
            RemapRule(
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
                    .exact,
                isEnabled:
                    false,
                isBidirectional:
                    true
            )

        let currentData =
            try JSONEncoder()
                .encode(
                    currentRule
                )

        var legacyObject =
            try XCTUnwrap(
                JSONSerialization
                    .jsonObject(
                        with:
                            currentData
                    )
                    as? [String: Any]
            )

        legacyObject.removeValue(
            forKey:
                "isEnabled"
        )

        let legacyData =
            try JSONSerialization
                .data(
                    withJSONObject:
                        legacyObject
                )

        let decodedRule =
            try JSONDecoder()
                .decode(
                    RemapRule.self,
                    from:
                        legacyData
                )

        XCTAssertTrue(
            decodedRule.isEnabled
        )

        XCTAssertTrue(
            decodedRule.isBidirectional
        )
    }

    func testEditorItemPreservesActivationAndReverseIndependently()
        throws
    {
        let originalRule =
            RemapRule(
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
                    .exact,
                isEnabled:
                    false,
                isBidirectional:
                    true
            )

        var editorItem =
            RemappingRuleEditorItem(
                rule:
                    originalRule
            )

        XCTAssertFalse(
            editorItem.isEnabled
        )

        XCTAssertTrue(
            editorItem.isBidirectional
        )

        editorItem.setEnabled(
            true
        )

        XCTAssertTrue(
            editorItem.isEnabled
        )

        XCTAssertTrue(
            editorItem.isBidirectional
        )

        editorItem.setBidirectional(
            false
        )

        XCTAssertTrue(
            editorItem.isEnabled
        )

        XCTAssertFalse(
            editorItem.isBidirectional
        )

        let convertedRule =
            try XCTUnwrap(
                editorItem.rule
            )

        XCTAssertTrue(
            convertedRule.isEnabled
        )

        XCTAssertFalse(
            convertedRule.isBidirectional
        )
    }

    func testEmptySessionHasUnavailableActivationSelectionState() {
        let session =
            RemappingRuleEditorSession()

        session.initialize(
            with:
                []
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .unavailable
        )
    }

    func testActivationSelectionStateAutomaticallyTransitionsBetweenOffMixedAndOn() {
        let session =
            makeActivationSession(
                activeStates: [
                    false,
                    false,
                    false
                ]
            )

        XCTAssertEqual(
            session.activationSelectionState,
            .disabled
        )

        setEnabled(
            true,
            forItemAt:
                0,
            in:
                session
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .mixed
        )

        setEnabled(
            true,
            forItemAt:
                1,
            in:
                session
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .mixed
        )

        setEnabled(
            true,
            forItemAt:
                2,
            in:
                session
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .enabled
        )

        setEnabled(
            false,
            forItemAt:
                1,
            in:
                session
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .mixed
        )

        setEnabled(
            false,
            forItemAt:
                0,
            in:
                session
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .mixed
        )

        setEnabled(
            false,
            forItemAt:
                2,
            in:
                session
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .disabled
        )
    }

    func testSettingEnabledForAllCreatesOneUndoableHistoryEntryAndPreservesReverseStates() {
        let session =
            makeActivationSession(
                activeStates: [
                    true,
                    false,
                    true
                ],
                reverseStates: [
                    true,
                    false,
                    true
                ]
            )

        let originalActiveStates =
            session.items.map(
                \.isEnabled
            )

        let originalReverseStates =
            session.items.map(
                \.isBidirectional
            )

        let historyEntryCountBeforeChange =
            session.historyEntryCount

        session.setEnabledForAll(
            false
        )

        XCTAssertEqual(
            session.historyEntryCount,
            historyEntryCountBeforeChange + 1
        )

        XCTAssertEqual(
            session.items.map(
                \.isEnabled
            ),
            [
                false,
                false,
                false
            ]
        )

        XCTAssertEqual(
            session.items.map(
                \.isBidirectional
            ),
            originalReverseStates
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .disabled
        )

        session.undo()

        XCTAssertEqual(
            session.items.map(
                \.isEnabled
            ),
            originalActiveStates
        )

        XCTAssertEqual(
            session.items.map(
                \.isBidirectional
            ),
            originalReverseStates
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .mixed
        )

        session.redo()

        XCTAssertEqual(
            session.items.map(
                \.isEnabled
            ),
            [
                false,
                false,
                false
            ]
        )

        XCTAssertEqual(
            session.items.map(
                \.isBidirectional
            ),
            originalReverseStates
        )
    }

    func testSettingEnabledForAllToCurrentStateDoesNotCreateHistory() {
        let session =
            makeActivationSession(
                activeStates: [
                    true,
                    true
                ]
            )

        let historyEntryCountBeforeChange =
            session.historyEntryCount

        session.setEnabledForAll(
            true
        )

        XCTAssertEqual(
            session.historyEntryCount,
            historyEntryCountBeforeChange
        )

        XCTAssertFalse(
            session.canUndo
        )

        XCTAssertEqual(
            session.activationSelectionState,
            .enabled
        )
    }

    func testEmptySessionHasUnavailableBidirectionalSelectionState() {
        let session =
            RemappingRuleEditorSession()

        session.initialize(
            with: []
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .unavailable
        )
    }

    func testBidirectionalSelectionStateAutomaticallyTransitionsBetweenOffMixedAndOn() {
        let session =
            makeSession(
                reverseStates: [
                    false,
                    false,
                    false
                ]
            )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .disabled
        )

        setBidirectional(
            true,
            forItemAt:
                0,
            in:
                session
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        setBidirectional(
            true,
            forItemAt:
                1,
            in:
                session
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        setBidirectional(
            true,
            forItemAt:
                2,
            in:
                session
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .enabled
        )

        setBidirectional(
            false,
            forItemAt:
                1,
            in:
                session
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        setBidirectional(
            false,
            forItemAt:
                0,
            in:
                session
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        setBidirectional(
            false,
            forItemAt:
                2,
            in:
                session
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .disabled
        )
    }

    func testSettingBidirectionalForAllCreatesOneUndoableHistoryEntry() {
        let session =
            makeSession(
                reverseStates: [
                    true,
                    false,
                    true
                ]
            )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        let mixedStates =
            session.items.map(
                \.isBidirectional
            )

        let historyEntryCountBeforeChange =
            session.historyEntryCount

        session.setBidirectionalForAll(
            true
        )

        XCTAssertEqual(
            session.historyEntryCount,
            historyEntryCountBeforeChange + 1
        )

        XCTAssertEqual(
            session.items.map(
                \.isBidirectional
            ),
            [
                true,
                true,
                true
            ]
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .enabled
        )

        session.undo()

        XCTAssertEqual(
            session.items.map(
                \.isBidirectional
            ),
            mixedStates
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .mixed
        )

        session.redo()

        XCTAssertEqual(
            session.items.map(
                \.isBidirectional
            ),
            [
                true,
                true,
                true
            ]
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .enabled
        )
    }

    func testSettingBidirectionalForAllToCurrentStateDoesNotCreateHistory() {
        let session =
            makeSession(
                reverseStates: [
                    false,
                    false
                ]
            )

        let historyEntryCountBeforeChange =
            session.historyEntryCount

        session.setBidirectionalForAll(
            false
        )

        XCTAssertEqual(
            session.historyEntryCount,
            historyEntryCountBeforeChange
        )

        XCTAssertFalse(
            session.canUndo
        )

        XCTAssertEqual(
            session.bidirectionalSelectionState,
            .disabled
        )
    }

    func testActiveSortingGroupsDisabledBeforeEnabledAndPreservesStableOrder() {
        let model =
            RemappingRulesPresentationModel()

        let enabledFirst =
            makeEditorItem(
                source:
                    KeyCode.v,
                destination:
                    KeyCode.w,
                isEnabled:
                    true,
                isBidirectional:
                    true
            )

        let disabledFirst =
            makeEditorItem(
                source:
                    KeyCode.b,
                destination:
                    KeyCode.j,
                isEnabled:
                    false,
                isBidirectional:
                    false
            )

        let enabledSecond =
            makeEditorItem(
                source:
                    KeyCode.n,
                destination:
                    KeyCode.r,
                isEnabled:
                    true,
                isBidirectional:
                    false
            )

        let disabledSecond =
            makeEditorItem(
                source:
                    CGKeyCode(
                        kVK_ANSI_M
                    ),
                destination:
                    CGKeyCode(
                        kVK_ANSI_K
                    ),
                isEnabled:
                    false,
                isBidirectional:
                    true
            )

        let originalItems = [
            enabledFirst,
            disabledFirst,
            enabledSecond,
            disabledSecond
        ]

        _ = model.selectSortColumn(
            .active
        )

        XCTAssertEqual(
            model.visibleItems(
                from:
                    originalItems
            )
            .map(
                \.id
            ),
            [
                disabledFirst.id,
                disabledSecond.id,
                enabledFirst.id,
                enabledSecond.id
            ]
        )

        _ = model.selectSortColumn(
            .active
        )

        XCTAssertEqual(
            model.visibleItems(
                from:
                    originalItems
            )
            .map(
                \.id
            ),
            [
                enabledFirst.id,
                enabledSecond.id,
                disabledFirst.id,
                disabledSecond.id
            ]
        )
    }

    func testReverseSortingGroupsDisabledBeforeEnabledAndPreservesStableOrder() {
        let model =
            RemappingRulesPresentationModel()

        let enabledFirst =
            makeEditorItem(
                source: KeyCode.v,
                destination: KeyCode.w,
                isBidirectional: true
            )

        let disabledFirst =
            makeEditorItem(
                source: KeyCode.b,
                destination: KeyCode.j,
                isBidirectional: false
            )

        let enabledSecond =
            makeEditorItem(
                source: KeyCode.n,
                destination: KeyCode.r,
                isBidirectional: true
            )

        let disabledSecond =
            makeEditorItem(
                source: CGKeyCode(kVK_ANSI_M),
                destination: CGKeyCode(kVK_ANSI_K),
                isBidirectional: false
            )

        let originalItems = [
            enabledFirst,
            disabledFirst,
            enabledSecond,
            disabledSecond
        ]

        _ = model.selectSortColumn(
            .reverse
        )

        XCTAssertEqual(
            model.visibleItems(
                from:
                    originalItems
            )
            .map(
                \.id
            ),
            [
                disabledFirst.id,
                disabledSecond.id,
                enabledFirst.id,
                enabledSecond.id
            ]
        )

        _ = model.selectSortColumn(
            .reverse
        )

        XCTAssertEqual(
            model.visibleItems(
                from:
                    originalItems
            )
            .map(
                \.id
            ),
            [
                enabledFirst.id,
                enabledSecond.id,
                disabledFirst.id,
                disabledSecond.id
            ]
        )
    }

    private func makeActivationSession(
        activeStates:
            [Bool],
        reverseStates:
            [Bool]? = nil
    ) -> RemappingRuleEditorSession {
        let session =
            RemappingRuleEditorSession()

        let sourceKeyCodes: [CGKeyCode] = [
            KeyCode.v,
            KeyCode.b,
            KeyCode.n,
            CGKeyCode(
                kVK_ANSI_M
            )
        ]

        let destinationKeyCodes: [CGKeyCode] = [
            KeyCode.w,
            KeyCode.j,
            KeyCode.r,
            CGKeyCode(
                kVK_ANSI_K
            )
        ]

        let rules =
            activeStates
                .enumerated()
                .map {
                    index,
                    isEnabled in

                    makeRule(
                        source:
                            sourceKeyCodes[
                                index
                            ],
                        destination:
                            destinationKeyCodes[
                                index
                            ],
                        isEnabled:
                            isEnabled,
                        isBidirectional:
                            reverseStates?[
                                index
                            ] ?? false
                    )
                }

        session.initialize(
            with:
                rules
        )

        return session
    }

    private func setEnabled(
        _ isEnabled:
            Bool,
        forItemAt index:
            Int,
        in session:
            RemappingRuleEditorSession
    ) {
        var item =
            session.items[
                index
            ]

        item.setEnabled(
            isEnabled
        )

        session.updateItem(
            item
        )
    }

    private func makeSession(
        reverseStates: [Bool]
    ) -> RemappingRuleEditorSession {
        let session =
            RemappingRuleEditorSession()

        let sourceKeyCodes: [CGKeyCode] = [
            KeyCode.v,
            KeyCode.b,
            KeyCode.n,
            CGKeyCode(kVK_ANSI_M)
        ]

        let destinationKeyCodes: [CGKeyCode] = [
            KeyCode.w,
            KeyCode.j,
            KeyCode.r,
            CGKeyCode(kVK_ANSI_K)
        ]

        let rules =
            reverseStates
                .enumerated()
                .map {
                    index,
                    isBidirectional in

                    makeRule(
                        source:
                            sourceKeyCodes[
                                index
                            ],
                        destination:
                            destinationKeyCodes[
                                index
                            ],
                        isBidirectional:
                            isBidirectional
                    )
                }

        session.initialize(
            with:
                rules
        )

        return session
    }

    private func setBidirectional(
        _ isBidirectional: Bool,
        forItemAt index: Int,
        in session:
            RemappingRuleEditorSession
    ) {
        var item =
            session.items[
                index
            ]

        item.setBidirectional(
            isBidirectional
        )

        session.updateItem(
            item
        )
    }

    private func makeRule(
        source: CGKeyCode,
        destination: CGKeyCode,
        isEnabled: Bool = true,
        isBidirectional: Bool
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
            matchingMode:
                .exact,
            isEnabled:
                isEnabled,
            isBidirectional:
                isBidirectional
        )
    }

    private func makeEditorItem(
        source: CGKeyCode,
        destination: CGKeyCode,
        isEnabled: Bool = true,
        isBidirectional: Bool
    ) -> RemappingRuleEditorItem {
        var item =
            RemappingRuleEditorItem(
                sourceCombination:
                    KeyCombination(
                        keyCode:
                            source
                    ),
                destinationCombination:
                    KeyCombination(
                        keyCode:
                            destination
                    ),
                matchingMode:
                    .exact,
                overrides: []
            )

        item.setEnabled(
            isEnabled
        )

        item.setBidirectional(
            isBidirectional
        )

        return item
    }
}
