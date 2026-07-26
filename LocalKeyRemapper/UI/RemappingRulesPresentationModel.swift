//
//  RemappingRulesPresentationModel.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/22/26.
//

import CoreGraphics
import Foundation

/// Owns presentation-only sorting and filtering state for the remapping-rules
/// window.
///
/// This model never modifies the editor session, persistent rules, rule
/// priority, exceptions, dirty state, or Undo/Redo history. It only derives
/// the collection of items that the rules window should currently display.
nonisolated final class RemappingRulesPresentationModel {

    enum SortColumn: Equatable {
        case source
        case destination
        case modifierBehavior
        case exceptions
        case reverse
        case issues
    }

    enum SortDirection: Equatable {
        case ascending
        case descending

        var reversed: SortDirection {
            switch self {
            case .ascending:
                return .descending

            case .descending:
                return .ascending
            }
        }
    }

    struct SortDescriptor: Equatable {
        let column: SortColumn
        let direction: SortDirection
    }

    private(set) var sortDescriptor: SortDescriptor?

    /// Filters use only the physical key code.
    private(set) var sourceFilterKeyCode: CGKeyCode?
    private(set) var destinationFilterKeyCode: CGKeyCode?

    /// Issue filters are presentation-only and never change rule validity.
    private(set) var showsOnlyValidationIssues =
        false

    private(set) var showsOnlyConfigurationWarnings =
        false

    var hasActiveIssueFilters: Bool {
        showsOnlyValidationIssues
            || showsOnlyConfigurationWarnings
    }

    var hasActiveFilters: Bool {
        sourceFilterKeyCode != nil
            || destinationFilterKeyCode != nil
            || hasActiveIssueFilters
    }

    @discardableResult
    func selectSortColumn(
        _ column: SortColumn
    ) -> SortDescriptor {
        let newDirection: SortDirection

        if let sortDescriptor,
           sortDescriptor.column == column {
            newDirection =
                sortDescriptor.direction.reversed
        } else {
            newDirection = .ascending
        }

        let newDescriptor =
            SortDescriptor(
                column: column,
                direction: newDirection
            )

        sortDescriptor = newDescriptor
        return newDescriptor
    }

    func clearSorting() {
        sortDescriptor = nil
    }

    func setSourceFilter(
        _ combination: KeyCombination?
    ) {
        sourceFilterKeyCode =
            combination?.keyCode
    }

    func setDestinationFilter(
        _ combination: KeyCombination?
    ) {
        destinationFilterKeyCode =
            combination?.keyCode
    }

    func clearSourceFilter() {
        sourceFilterKeyCode = nil
    }

    func clearDestinationFilter() {
        destinationFilterKeyCode = nil
    }

    func toggleValidationIssueFilter() {
        showsOnlyValidationIssues.toggle()
    }

    func toggleConfigurationWarningFilter() {
        showsOnlyConfigurationWarnings.toggle()
    }

    func clearIssueFilters() {
        showsOnlyValidationIssues =
            false

        showsOnlyConfigurationWarnings =
            false
    }

    func clearAllFilters() {
        sourceFilterKeyCode = nil
        destinationFilterKeyCode = nil
        clearIssueFilters()
    }

    /// When both issue filters are enabled, a rule is visible when it has a
    /// validation issue OR a configuration warning.
    func visibleItems(
        from items:
            [RemappingRuleEditorItem],
        validationIssueItemIDs:
            Set<UUID> = [],
        configurationWarningItemIDs:
            Set<UUID> = []
    ) -> [RemappingRuleEditorItem] {
        let filteredItems =
            items.filter {
                item in

                matchesSourceFilter(
                    item
                )
                    && matchesDestinationFilter(
                        item
                    )
                    && matchesIssueFilters(
                        item,
                        validationIssueItemIDs:
                            validationIssueItemIDs,
                        configurationWarningItemIDs:
                            configurationWarningItemIDs
                    )
            }

        guard let sortDescriptor else {
            return filteredItems
        }

        return filteredItems
            .enumerated()
            .sorted {
                first,
                second in

                let comparison =
                    Self.compare(
                        first.element,
                        second.element,
                        using:
                            sortDescriptor,
                        validationIssueItemIDs:
                            validationIssueItemIDs,
                        configurationWarningItemIDs:
                            configurationWarningItemIDs
                    )

                if comparison == .orderedSame {
                    return first.offset
                        < second.offset
                }

                return comparison
                    == .orderedAscending
            }
            .map(
                \.element
            )
    }

    private func matchesSourceFilter(
        _ item: RemappingRuleEditorItem
    ) -> Bool {
        guard let sourceFilterKeyCode else {
            return true
        }

        return item
            .sourceCombination?
            .keyCode
            == sourceFilterKeyCode
    }

    private func matchesDestinationFilter(
        _ item: RemappingRuleEditorItem
    ) -> Bool {
        guard let destinationFilterKeyCode else {
            return true
        }

        return item
            .destinationCombination?
            .keyCode
            == destinationFilterKeyCode
    }

    private func matchesIssueFilters(
        _ item: RemappingRuleEditorItem,
        validationIssueItemIDs:
            Set<UUID>,
        configurationWarningItemIDs:
            Set<UUID>
    ) -> Bool {
        guard hasActiveIssueFilters else {
            return true
        }

        let hasValidationIssue =
            showsOnlyValidationIssues
                && validationIssueItemIDs
                    .contains(
                        item.id
                    )

        let hasConfigurationWarning =
            showsOnlyConfigurationWarnings
                && configurationWarningItemIDs
                    .contains(
                        item.id
                    )

        return hasValidationIssue
            || hasConfigurationWarning
    }

    private static func compare(
        _ first: RemappingRuleEditorItem,
        _ second: RemappingRuleEditorItem,
        using descriptor: SortDescriptor,
        validationIssueItemIDs:
            Set<UUID>,
        configurationWarningItemIDs:
            Set<UUID>
    ) -> ComparisonResult {
        switch descriptor.column {
        case .source:
            return compareOptionalCombinations(
                first.sourceCombination,
                second.sourceCombination,
                direction:
                    descriptor.direction
            )

        case .destination:
            return compareOptionalCombinations(
                first.destinationCombination,
                second.destinationCombination,
                direction:
                    descriptor.direction
            )

        case .modifierBehavior:
            let comparison =
                compareValues(
                    modifierBehaviorSortValue(
                        first.matchingMode
                    ),
                    modifierBehaviorSortValue(
                        second.matchingMode
                    )
                )

            return applying(
                descriptor.direction,
                to:
                    comparison
            )

        case .exceptions:
            let comparison =
                compareValues(
                    first.overrides.count,
                    second.overrides.count
                )

            return applying(
                descriptor.direction,
                to:
                    comparison
            )

        case .reverse:
            let comparison =
                compareValues(
                    first.isBidirectional
                        ? 1
                        : 0,
                    second.isBidirectional
                        ? 1
                        : 0
                )

            return applying(
                descriptor.direction,
                to:
                    comparison
            )

        case .issues:
            let comparison =
                compareValues(
                    issueSortValue(
                        for: first.id,
                        validationIssueItemIDs:
                            validationIssueItemIDs,
                        configurationWarningItemIDs:
                            configurationWarningItemIDs
                    ),
                    issueSortValue(
                        for: second.id,
                        validationIssueItemIDs:
                            validationIssueItemIDs,
                        configurationWarningItemIDs:
                            configurationWarningItemIDs
                    )
                )

            return applying(
                descriptor.direction,
                to:
                    comparison
            )
        }
    }

    /// Sort order used by the Issues column:
    /// no issue, warning, validation error, validation error + warning.
    private static func issueSortValue(
        for itemID: UUID,
        validationIssueItemIDs:
            Set<UUID>,
        configurationWarningItemIDs:
            Set<UUID>
    ) -> Int {
        let hasValidationIssue =
            validationIssueItemIDs.contains(
                itemID
            )

        let hasConfigurationWarning =
            configurationWarningItemIDs.contains(
                itemID
            )

        switch (
            hasValidationIssue,
            hasConfigurationWarning
        ) {
        case (false, false):
            return 0

        case (false, true):
            return 1

        case (true, false):
            return 2

        case (true, true):
            return 3
        }
    }

    private static func compareOptionalCombinations(
        _ first: KeyCombination?,
        _ second: KeyCombination?,
        direction: SortDirection
    ) -> ComparisonResult {
        switch (
            first,
            second
        ) {
        case (
            nil,
            nil
        ):
            return .orderedSame

        case (
            nil,
            _
        ):
            return .orderedDescending

        case (
            _,
            nil
        ):
            return .orderedAscending

        case (
            let firstCombination?,
            let secondCombination?
        ):
            return applying(
                direction,
                to:
                    compareCombinations(
                        firstCombination,
                        secondCombination
                    )
            )
        }
    }

    private static func compareCombinations(
        _ first: KeyCombination,
        _ second: KeyCombination
    ) -> ComparisonResult {
        let firstKeyName =
            KeyboardLayoutKeyName.name(
                for:
                    first.keyCode
            )

        let secondKeyName =
            KeyboardLayoutKeyName.name(
                for:
                    second.keyCode
            )

        let nameComparison =
            firstKeyName
                .localizedStandardCompare(
                    secondKeyName
                )

        if nameComparison
            != .orderedSame
        {
            return nameComparison
        }

        let keyCodeComparison =
            compareValues(
                first.keyCode,
                second.keyCode
            )

        if keyCodeComparison
            != .orderedSame
        {
            return keyCodeComparison
        }

        return compareValues(
            first.modifiers.rawValue,
            second.modifiers.rawValue
        )
    }

    private static func modifierBehaviorSortValue(
        _ matchingMode:
            RemapMatchingMode
    ) -> String {
        switch matchingMode {
        case .exact:
            return "Exact only"

        case .preserveModifiers:
            return "Preserve modifiers"
        }
    }

    private static func compareValues<
        Value:
            Comparable
    >(
        _ first: Value,
        _ second: Value
    ) -> ComparisonResult {
        if first < second {
            return .orderedAscending
        }

        if first > second {
            return .orderedDescending
        }

        return .orderedSame
    }

    private static func applying(
        _ direction:
            SortDirection,
        to comparison:
            ComparisonResult
    ) -> ComparisonResult {
        guard
            direction
                == .descending
        else {
            return comparison
        }

        switch comparison {
        case .orderedAscending:
            return .orderedDescending

        case .orderedDescending:
            return .orderedAscending

        case .orderedSame:
            return .orderedSame
        }
    }
}
