//
//  RemappingRuleEditorSession.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/20/26.
//

import Foundation

/// Owns the editable remapping rules and their session-only history.
///
/// One instance is retained by `AppCoordinator` for the lifetime of the
/// running application process. Closing or recreating the main window does
/// not destroy this object, while terminating the process naturally does.
nonisolated final class RemappingRuleEditorSession {

    /// Represents the combined bidirectional state of all editor items.
    ///
    /// This is used by the global Reverse switch:
    /// - unavailable: there are no rules;
    /// - disabled: every rule is one-directional;
    /// - mixed: only some rules are bidirectional;
    /// - enabled: every rule is bidirectional.
    enum BidirectionalSelectionState:
        Equatable
    {
        case unavailable
        case disabled
        case mixed
        case enabled
    }

    var onChange: (() -> Void)?

    private let history:
        RuleEditorHistory

    private(set) var items:
        [RemappingRuleEditorItem] = []

    private(set) var savedRules:
        [RemapRule] = []

    private(set) var isInitialized =
        false

    init(
        history:
            RuleEditorHistory = RuleEditorHistory()
    ) {
        self.history =
            history
    }

    var canUndo: Bool {
        history.canUndo
    }

    var canRedo: Bool {
        history.canRedo
    }

    var historyEntryCount: Int {
        history.totalEntryCount
    }

    var estimatedHistoryPayloadSize: Int {
        history.totalEstimatedPayloadSize
    }

    /// Returns the combined Reverse state for the complete collection.
    ///
    /// The result always considers every rule in the session, including
    /// rules that are currently hidden by sorting or filtering.
    var bidirectionalSelectionState:
        BidirectionalSelectionState
    {
        guard
            !items.isEmpty
        else {
            return .unavailable
        }

        let enabledCount =
            items.reduce(
                into: 0
            ) {
                count,
                item in

                if item.isBidirectional {
                    count += 1
                }
            }

        if enabledCount == 0 {
            return .disabled
        }

        if enabledCount == items.count {
            return .enabled
        }

        return .mixed
    }

    /// Returns every current item as a rule only when no row is incomplete.
    var completeRules:
        [RemapRule]?
    {
        let rules =
            items.compactMap {
                $0.rule
            }

        guard
            rules.count
                == items.count
        else {
            return nil
        }

        return rules
    }

    /// Indicates whether the editor differs from the last loaded or saved
    /// persistent rule collection.
    var hasUnsavedChanges: Bool {
        guard
            let completeRules
        else {
            return true
        }

        return Self.normalizedRules(
            completeRules
        ) != Self.normalizedRules(
            savedRules
        )
    }

    /// Loads the persistent rules once at the beginning of the app session.
    ///
    /// A second call is ignored so reopening the window cannot overwrite the
    /// in-memory editor state or its Undo and Redo history.
    func initialize(
        with rules:
            [RemapRule]
    ) {
        guard
            !isInitialized
        else {
            return
        }

        items =
            rules.map {
                RemappingRuleEditorItem(
                    rule:
                        $0
                )
            }

        savedRules =
            rules

        history.clear()

        isInitialized =
            true

        onChange?()
    }

    @discardableResult
    func insertEmptyItem(
        at requestedIndex:
            Int? = nil
    ) -> UUID {
        let item =
            RemappingRuleEditorItem()

        let index =
            min(
                max(
                    requestedIndex
                        ?? items.count,
                    0
                ),
                items.count
            )

        applyNewAction(
            .insert(
                item:
                    item,
                index:
                    index
            )
        )

        return item.id
    }

    func removeItem(
        id:
            UUID
    ) {
        guard
            let index =
                items.firstIndex(
                    where: {
                        $0.id == id
                    }
                )
        else {
            return
        }

        applyNewAction(
            .remove(
                item:
                    items[index],
                index:
                    index
            )
        )
    }

    func updateItem(
        _ updatedItem:
            RemappingRuleEditorItem
    ) {
        guard
            let index =
                items.firstIndex(
                    where: {
                        $0.id
                            == updatedItem.id
                    }
                )
        else {
            return
        }

        let previousItem =
            items[index]

        guard
            previousItem
                != updatedItem
        else {
            return
        }

        applyNewAction(
            .update(
                before:
                    previousItem,
                after:
                    updatedItem
            )
        )
    }

    /// Enables or disables Reverse on every rule as one Undo/Redo action.
    ///
    /// This applies to the complete editor collection, not only the rows
    /// currently visible after filtering.
    func setBidirectionalForAll(
        _ isEnabled:
            Bool
    ) {
        let updatedItems =
            items.map {
                item in

                var updatedItem =
                    item

                updatedItem.setBidirectional(
                    isEnabled
                )

                return updatedItem
            }

        guard
            updatedItems
                != items
        else {
            return
        }

        applyNewAction(
            .replaceAll(
                before:
                    items,
                after:
                    updatedItems
            )
        )
    }

    /// Restores the last loaded or saved rules as one reversible operation.
    func restoreSavedRules() {
        guard
            hasUnsavedChanges
        else {
            return
        }

        let restoredItems =
            savedRules.map {
                RemappingRuleEditorItem(
                    rule:
                        $0
                )
            }

        applyNewAction(
            .replaceAll(
                before:
                    items,
                after:
                    restoredItems
            )
        )
    }

    /// Updates the saved baseline without clearing Undo or Redo.
    func markCurrentRulesAsSaved(
        _ rules:
            [RemapRule]
    ) {
        savedRules =
            rules

        onChange?()
    }

    func undo() {
        guard
            let action =
                history.takeUndoAction()
        else {
            return
        }

        items =
            action.applyingUndo(
                to:
                    items
            )

        onChange?()
    }

    func redo() {
        guard
            let action =
                history.takeRedoAction()
        else {
            return
        }

        items =
            action.applyingRedo(
                to:
                    items
            )

        onChange?()
    }

    private func applyNewAction(
        _ action:
            RuleEditorAction
    ) {
        history.record(
            action
        )

        items =
            action.applyingRedo(
                to:
                    items
            )

        onChange?()
    }

    private static func normalizedRules(
        _ rules:
            [RemapRule]
    ) -> [RemapRule] {
        let normalizedRules =
            rules.map {
                rule in

                RemapRule(
                    source:
                        rule.source,
                    destination:
                        rule.destination,
                    matchingMode:
                        rule.matchingMode,
                    overrides:
                        normalizedOverrides(
                            rule.overrides
                        ),
                    isBidirectional:
                        rule.isBidirectional
                )
            }

        return normalizedRules.sorted {
            first,
            second in

            if first.source.keyCode
                != second.source.keyCode
            {
                return first.source.keyCode
                    < second.source.keyCode
            }

            if first.source.modifiers.rawValue
                != second.source.modifiers.rawValue
            {
                return first
                    .source
                    .modifiers
                    .rawValue
                    < second
                        .source
                        .modifiers
                        .rawValue
            }

            if first.matchingMode.rawValue
                != second.matchingMode.rawValue
            {
                return first.matchingMode.rawValue
                    < second.matchingMode.rawValue
            }

            if first.destination.keyCode
                != second.destination.keyCode
            {
                return first.destination.keyCode
                    < second.destination.keyCode
            }

            if first.destination.modifiers.rawValue
                != second.destination.modifiers.rawValue
            {
                return first
                    .destination
                    .modifiers
                    .rawValue
                    < second
                        .destination
                        .modifiers
                        .rawValue
            }

            if first.isBidirectional
                != second.isBidirectional
            {
                return first.isBidirectional
                    == false
            }

            return false
        }
    }

    private static func normalizedOverrides(
        _ overrides:
            [RemapOverride]
    ) -> [RemapOverride] {
        overrides.sorted {
            first,
            second in

            if first.source.keyCode
                != second.source.keyCode
            {
                return first.source.keyCode
                    < second.source.keyCode
            }

            if first.source.modifiers.rawValue
                != second.source.modifiers.rawValue
            {
                return first
                    .source
                    .modifiers
                    .rawValue
                    < second
                        .source
                        .modifiers
                        .rawValue
            }

            if first.isEnabled
                != second.isEnabled
            {
                return first.isEnabled
                    == false
            }

            return actionSortKey(
                first.action
            ) < actionSortKey(
                second.action
            )
        }
    }

    private static func actionSortKey(
        _ action:
            RemapAction
    ) -> String {
        switch action {
        case .passThrough:
            return "0"

        case .replaceWith(
            let destination
        ):
            return
                "1-\(destination.keyCode)-"
                + "\(destination.modifiers.rawValue)"
        }
    }
}
