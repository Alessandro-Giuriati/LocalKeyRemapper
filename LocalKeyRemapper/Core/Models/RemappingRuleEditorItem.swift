//
//  RemappingRuleEditorItem.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/20/26.
//

import Foundation

/// Represents one row in the remapping rule editor.
///
/// Unlike `RemapRule`, an editor item may be incomplete while the user is
/// still choosing its source or destination combination. The identifier is
/// valid only for the current application process and is never persisted.
nonisolated struct RemappingRuleEditorItem:
    Equatable
{
    let id: UUID
    var sourceCombination: KeyCombination?
    var destinationCombination: KeyCombination?
    var matchingMode: RemapMatchingMode
    var overrides: [RemapOverride]

    init(
        id: UUID = UUID(),
        sourceCombination: KeyCombination? = nil,
        destinationCombination: KeyCombination? = nil,
        matchingMode: RemapMatchingMode = .exact,
        overrides: [RemapOverride] = []
    ) {
        self.id = id
        self.sourceCombination = sourceCombination
        self.destinationCombination = destinationCombination
        self.matchingMode = matchingMode
        self.overrides = overrides
    }

    init(
        id: UUID = UUID(),
        rule: RemapRule
    ) {
        self.init(
            id: id,
            sourceCombination: rule.source,
            destinationCombination: rule.destination,
            matchingMode: rule.matchingMode,
            overrides: rule.overrides
        )
    }

    /// Returns a persistable rule only when both endpoints are complete.
    var rule: RemapRule? {
        guard
            let sourceCombination,
            let destinationCombination
        else {
            return nil
        }

        return RemapRule(
            source: sourceCombination,
            destination: destinationCombination,
            matchingMode: matchingMode,
            overrides: overrides
        )
    }
}
