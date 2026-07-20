//
//  RuleEditorAction.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/20/26.
//

import Foundation

/// Represents one reversible change made to the remapping rule editor.
///
/// Normal edits store only the affected item. `replaceAll` is reserved for
/// genuinely global operations such as discarding all unsaved changes.
nonisolated enum RuleEditorAction:
    Equatable
{
    case insert(
        item: RemappingRuleEditorItem,
        index: Int
    )

    case remove(
        item: RemappingRuleEditorItem,
        index: Int
    )

    case update(
        before: RemappingRuleEditorItem,
        after: RemappingRuleEditorItem
    )

    case replaceAll(
        before: [RemappingRuleEditorItem],
        after: [RemappingRuleEditorItem]
    )

    /// Deterministic estimate used to enforce the session memory limit.
    ///
    /// This is intentionally an estimate rather than a claim about Swift's
    /// exact heap representation. It remains stable and testable while
    /// accounting for identifiers, combinations, arrays, and overrides.
    var estimatedPayloadSize: Int {
        let actionOverhead = 32

        switch self {
        case .insert(let item, _),
             .remove(let item, _):
            return actionOverhead
                + Self.estimatedSize(of: item)
                + MemoryLayout<Int>.size

        case .update(let before, let after):
            return actionOverhead
                + Self.estimatedSize(of: before)
                + Self.estimatedSize(of: after)

        case .replaceAll(let before, let after):
            return actionOverhead
                + Self.estimatedSize(of: before)
                + Self.estimatedSize(of: after)
        }
    }

    func applyingUndo(
        to currentItems: [RemappingRuleEditorItem]
    ) -> [RemappingRuleEditorItem] {
        switch self {
        case .insert(let item, _):
            return Self.removing(
                itemID: item.id,
                from: currentItems
            )

        case .remove(let item, let index):
            return Self.inserting(
                item,
                at: index,
                into: currentItems
            )

        case .update(let before, _):
            return Self.replacing(
                itemID: before.id,
                with: before,
                in: currentItems
            )

        case .replaceAll(let before, _):
            return before
        }
    }

    func applyingRedo(
        to currentItems: [RemappingRuleEditorItem]
    ) -> [RemappingRuleEditorItem] {
        switch self {
        case .insert(let item, let index):
            return Self.inserting(
                item,
                at: index,
                into: currentItems
            )

        case .remove(let item, _):
            return Self.removing(
                itemID: item.id,
                from: currentItems
            )

        case .update(_, let after):
            return Self.replacing(
                itemID: after.id,
                with: after,
                in: currentItems
            )

        case .replaceAll(_, let after):
            return after
        }
    }

    private static func inserting(
        _ item: RemappingRuleEditorItem,
        at index: Int,
        into currentItems: [RemappingRuleEditorItem]
    ) -> [RemappingRuleEditorItem] {
        var updatedItems = currentItems

        if let existingIndex = updatedItems.firstIndex(
            where: { $0.id == item.id }
        ) {
            updatedItems.remove(at: existingIndex)
        }

        let safeIndex = min(
            max(index, 0),
            updatedItems.count
        )

        updatedItems.insert(
            item,
            at: safeIndex
        )

        return updatedItems
    }

    private static func removing(
        itemID: UUID,
        from currentItems: [RemappingRuleEditorItem]
    ) -> [RemappingRuleEditorItem] {
        currentItems.filter {
            $0.id != itemID
        }
    }

    private static func replacing(
        itemID: UUID,
        with replacement: RemappingRuleEditorItem,
        in currentItems: [RemappingRuleEditorItem]
    ) -> [RemappingRuleEditorItem] {
        guard let index = currentItems.firstIndex(
            where: { $0.id == itemID }
        ) else {
            return currentItems
        }

        var updatedItems = currentItems
        updatedItems[index] = replacement
        return updatedItems
    }

    private static func estimatedSize(
        of items: [RemappingRuleEditorItem]
    ) -> Int {
        let arrayOverhead = 24

        return arrayOverhead
            + items.reduce(0) {
                $0 + estimatedSize(of: $1)
            }
    }

    private static func estimatedSize(
        of item: RemappingRuleEditorItem
    ) -> Int {
        let itemOverhead = 48
        let optionalCombinationSize = 16
        let overridesArrayOverhead = 24

        return itemOverhead
            + optionalCombinationSize
            + optionalCombinationSize
            + overridesArrayOverhead
            + item.overrides.reduce(0) {
                $0 + estimatedSize(of: $1)
            }
    }

    private static func estimatedSize(
        of remapOverride: RemapOverride
    ) -> Int {
        let overrideOverhead = 24
        let sourceCombinationSize = 8

        switch remapOverride.action {
        case .passThrough:
            return overrideOverhead
                + sourceCombinationSize
                + 1

        case .replaceWith:
            return overrideOverhead
                + sourceCombinationSize
                + 8
        }
    }
}
