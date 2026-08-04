//
//  RemappingRuleEditorSession.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/20/26.
//

import Foundation

/// Owns the editable remapping rules and their session-only history.
///
/// A session remains alive while its profile has state worth preserving, such
/// as unsaved changes or Undo/Redo history. Clean history-free sessions may be
/// discarded and recreated from local persistence by the profile registry.
nonisolated final class RemappingRuleEditorSession {

    /// Represents the combined activation state of all editor items.
    ///
    /// This is used by the global Active switch:
    /// - unavailable: there are no rules;
    /// - disabled: every rule is disabled;
    /// - mixed: only some rules are enabled;
    /// - enabled: every rule is enabled.
    enum ActivationSelectionState:
        Equatable
    {
        case unavailable
        case disabled
        case mixed
        case enabled
    }

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

    /// Values derived from the complete editor collection.
    ///
    /// They are calculated together in one pass and reused until the item
    /// collection changes. This avoids repeatedly scanning every rule while
    /// the window refreshes headers, validation, status, and Save state.
    private struct DerivedState {
        let activationSelectionState:
            ActivationSelectionState

        let bidirectionalSelectionState:
            BidirectionalSelectionState

        let completeRules:
            [RemapRule]?
    }

    /// Cached dirty-state result for one exact editor and saved-baseline pair.
    private struct UnsavedChangesCache {
        let contentRevision:
            UInt64

        let savedBaselineRevision:
            UInt64

        let value:
            Bool
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

    /// Changes only when the editable item collection changes.
    ///
    /// Presentation code can use this lightweight value as a cache key instead
    /// of comparing or reprocessing the complete rule collection.
    private(set) var contentRevision:
        UInt64 = 0

    private var savedBaselineRevision:
        UInt64 = 0

    private var normalizedSavedRules:
        [RemapRule] = []

    private var cachedDerivedState:
        (
            revision: UInt64,
            value: DerivedState
        )?

    private var cachedUnsavedChanges:
        UnsavedChangesCache?

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

    /// Returns the combined Active state for the complete collection.
    ///
    /// The result always considers every rule in the session, including
    /// rules that are currently hidden by sorting or filtering.
    var activationSelectionState:
        ActivationSelectionState
    {
        derivedState
            .activationSelectionState
    }

    /// Returns the combined Reverse state for the complete collection.
    ///
    /// The result always considers every rule in the session, including
    /// rules that are currently hidden by sorting or filtering.
    var bidirectionalSelectionState:
        BidirectionalSelectionState
    {
        derivedState
            .bidirectionalSelectionState
    }

    /// Returns every current item as a rule only when no row is incomplete.
    var completeRules:
        [RemapRule]?
    {
        derivedState
            .completeRules
    }

    /// Indicates whether the editor differs from the last loaded or saved
    /// persistent rule collection.
    ///
    /// Normalization and sorting are performed at most once for each unique
    /// combination of editor content and saved baseline.
    var hasUnsavedChanges: Bool {
        if let cachedUnsavedChanges,
           cachedUnsavedChanges.contentRevision
            == contentRevision,
           cachedUnsavedChanges.savedBaselineRevision
            == savedBaselineRevision
        {
            return cachedUnsavedChanges.value
        }

        let value:
            Bool

        if let completeRules =
            derivedState.completeRules
        {
            value =
                Self.normalizedRules(
                    completeRules
                ) != normalizedSavedRules
        } else {
            value =
                true
        }

        cachedUnsavedChanges =
            UnsavedChangesCache(
                contentRevision:
                    contentRevision,
                savedBaselineRevision:
                    savedBaselineRevision,
                value:
                    value
            )

        return value
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

        normalizedSavedRules =
            Self.normalizedRules(
                rules
            )

        history.clear()

        isInitialized =
            true

        recordContentChange()
        recordSavedBaselineChange()

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

    /// Enables or disables every rule as one Undo/Redo action.
    ///
    /// This applies to the complete editor collection, not only the rows
    /// currently visible after filtering.
    func setEnabledForAll(
        _ isEnabled:
            Bool
    ) {
        let updatedItems =
            items.map {
                item in

                var updatedItem =
                    item

                updatedItem.setEnabled(
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

        normalizedSavedRules =
            Self.normalizedRules(
                rules
            )

        recordSavedBaselineChange()

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

        recordContentChange()

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

        recordContentChange()

        onChange?()
    }

    private var derivedState:
        DerivedState
    {
        if let cachedDerivedState,
           cachedDerivedState.revision
            == contentRevision
        {
            return cachedDerivedState.value
        }

        var completeRules:
            [RemapRule] = []

        completeRules.reserveCapacity(
            items.count
        )

        var containsIncompleteItem =
            false

        var enabledCount =
            0

        var bidirectionalCount =
            0

        for item in items {
            if item.isEnabled {
                enabledCount += 1
            }

            if item.isBidirectional {
                bidirectionalCount += 1
            }

            if let rule =
                item.rule
            {
                completeRules.append(
                    rule
                )
            } else {
                containsIncompleteItem =
                    true
            }
        }

        let state =
            DerivedState(
                activationSelectionState:
                    Self.activationSelectionState(
                        itemCount:
                            items.count,
                        enabledCount:
                            enabledCount
                    ),
                bidirectionalSelectionState:
                    Self.bidirectionalSelectionState(
                        itemCount:
                            items.count,
                        enabledCount:
                            bidirectionalCount
                    ),
                completeRules:
                    containsIncompleteItem
                        ? nil
                        : completeRules
            )

        cachedDerivedState =
            (
                revision:
                    contentRevision,
                value:
                    state
            )

        return state
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

        recordContentChange()

        onChange?()
    }

    private func recordContentChange() {
        contentRevision &+=
            1

        cachedDerivedState =
            nil

        cachedUnsavedChanges =
            nil
    }

    private func recordSavedBaselineChange() {
        savedBaselineRevision &+=
            1

        cachedUnsavedChanges =
            nil
    }

    private static func activationSelectionState(
        itemCount:
            Int,
        enabledCount:
            Int
    ) -> ActivationSelectionState {
        guard
            itemCount > 0
        else {
            return .unavailable
        }

        if enabledCount == 0 {
            return .disabled
        }

        if enabledCount == itemCount {
            return .enabled
        }

        return .mixed
    }

    private static func bidirectionalSelectionState(
        itemCount:
            Int,
        enabledCount:
            Int
    ) -> BidirectionalSelectionState {
        guard
            itemCount > 0
        else {
            return .unavailable
        }

        if enabledCount == 0 {
            return .disabled
        }

        if enabledCount == itemCount {
            return .enabled
        }

        return .mixed
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
                    isEnabled:
                        rule.isEnabled,
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

            if first.isEnabled
                != second.isEnabled
            {
                return first.isEnabled
                    == false
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
