//
//  RemappingConfigurationWarningAssessment.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/23/26.
//

import Foundation

/// Associates non-blocking configuration warnings with the editor items and
/// stored exceptions that produced them.
///
/// Assessment is deterministic and read-only. It does not modify editor data,
/// presentation state, persistence, dirty state, or Undo/Redo history.
nonisolated struct RemappingConfigurationWarningAssessment:
    Equatable
{
    /// Warning information for one standalone exception collection.
    struct ExceptionAssessment:
        Equatable
    {
        let warning:
            KeyCombinationConfigurationWarning?

        let affectedIndexes:
            Set<Int>

        var hasWarning: Bool {
            warning != nil
        }

        func affectsException(
            at index: Int
        ) -> Bool {
            affectedIndexes.contains(
                index
            )
        }
    }

    /// The first warning type found in the complete in-memory editor state.
    ///
    /// The current warning policy contains one warning category, but keeping
    /// the warning value here allows the assessment to remain compatible with
    /// additional warning categories in the future.
    let warning:
        KeyCombinationConfigurationWarning?

    /// Every editor item associated with the active warning.
    ///
    /// A parent item is included when the warning originates from the rule
    /// itself or from any of its stored exceptions.
    let affectedRuleIDs:
        Set<UUID>

    /// Warning-producing exception indexes grouped by their parent item ID.
    ///
    /// Indexes refer to the stored order inside each editor item's `overrides`
    /// array. Sorting and filtering the visible rule rows do not change them.
    let affectedExceptionIndexesByRuleID:
        [UUID: Set<Int>]

    var hasWarning: Bool {
        warning != nil
    }

    /// Evaluates the complete editor state, including items hidden by active
    /// presentation filters and combinations belonging to incomplete rows.
    ///
    /// Stored exceptions are inspected regardless of whether they are enabled
    /// or whether their parent currently uses Exact only or Preserve Modifiers.
    init(
        items:
            [RemappingRuleEditorItem]
    ) {
        var firstWarning:
            KeyCombinationConfigurationWarning?

        var affectedRuleIDs =
            Set<UUID>()

        var affectedExceptionIndexesByRuleID:
            [UUID: Set<Int>] = [:]

        for item in items {
            var ruleIsAffected =
                false

            if let itemWarning =
                Self.warning(
                    for:
                        item.sourceCombination
                )
            {
                firstWarning =
                    firstWarning
                    ?? itemWarning

                ruleIsAffected =
                    true
            }

            if let itemWarning =
                Self.warning(
                    for:
                        item.destinationCombination
                )
            {
                firstWarning =
                    firstWarning
                    ?? itemWarning

                ruleIsAffected =
                    true
            }

            let exceptionAssessment =
                Self.assess(
                    overrides:
                        item.overrides
                )

            if let exceptionWarning =
                exceptionAssessment.warning
            {
                firstWarning =
                    firstWarning
                    ?? exceptionWarning

                ruleIsAffected =
                    true

                affectedExceptionIndexesByRuleID[
                    item.id
                ] =
                    exceptionAssessment
                        .affectedIndexes
            }

            if ruleIsAffected {
                affectedRuleIDs.insert(
                    item.id
                )
            }
        }

        warning =
            firstWarning

        self.affectedRuleIDs =
            affectedRuleIDs

        self.affectedExceptionIndexesByRuleID =
            affectedExceptionIndexesByRuleID
    }

    func affectsRule(
        id: UUID
    ) -> Bool {
        affectedRuleIDs.contains(
            id
        )
    }

    func affectedExceptionIndexes(
        forRuleID ruleID: UUID
    ) -> Set<Int> {
        affectedExceptionIndexesByRuleID[
            ruleID
        ] ?? []
    }

    /// Evaluates one exception collection while preserving its stored order.
    static func assess(
        overrides:
            [RemapOverride]
    ) -> ExceptionAssessment {
        var firstWarning:
            KeyCombinationConfigurationWarning?

        var affectedIndexes =
            Set<Int>()

        for (
            index,
            remapOverride
        ) in overrides.enumerated() {
            guard
                let overrideWarning =
                    KeyCombinationConfigurationWarningPolicy
                        .warning(
                            for:
                                remapOverride
                        )
            else {
                continue
            }

            firstWarning =
                firstWarning
                ?? overrideWarning

            affectedIndexes.insert(
                index
            )
        }

        return ExceptionAssessment(
            warning:
                firstWarning,
            affectedIndexes:
                affectedIndexes
        )
    }

    private static func warning(
        for combination:
            KeyCombination?
    ) -> KeyCombinationConfigurationWarning? {
        guard let combination else {
            return nil
        }

        return
            KeyCombinationConfigurationWarningPolicy
                .warning(
                    for:
                        combination
                )
    }
}
