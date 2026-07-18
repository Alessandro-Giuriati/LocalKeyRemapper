//
//  RemappingEngine.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import CoreGraphics

/// Contains the pure keyboard remapping logic.
///
/// This class does not intercept keyboard events, access storage,
/// update the user interface, or record keyboard input.
nonisolated final class RemappingEngine {

    /// Exact combination rules and exact overrides.
    private var exactMappings:
        [KeyCombination: RemapAction] = [:]

    /// Modifier-preserving rules indexed by physical source key.
    private var preservingMappings:
        [CGKeyCode: CGKeyCode] = [:]

    /// Combinations reserved for application-level commands.
    ///
    /// Reserved combinations always pass through unchanged.
    /// A normal remapping rule is also prevented from producing
    /// a reserved combination as its destination.
    private var reservedCombinations:
        Set<KeyCombination> = []

    init(
        rules:
            [RemapRule] = []
    ) {
        replaceRules(
            rules
        )
    }

    /// Replaces the combinations that must never be remapped
    /// or produced by normal remapping rules.
    ///
    /// The collection is prepared outside keyboard-event processing,
    /// keeping event-time lookup minimal.
    func replaceReservedCombinations(
        _ combinations:
            Set<KeyCombination>
    ) {
        reservedCombinations =
            combinations
    }

    /// Replaces all currently loaded remapping rules.
    ///
    /// Rules are compiled into dictionaries before keyboard events
    /// are processed, keeping event-time work minimal.
    func replaceRules(
        _ rules:
            [RemapRule]
    ) {
        var newExactMappings:
            [KeyCombination: RemapAction] = [:]

        var newPreservingMappings:
            [CGKeyCode: CGKeyCode] = [:]

        for rule in rules {
            switch rule.matchingMode {
            case .exact:
                newExactMappings[
                    rule.source
                ] =
                    .replaceWith(
                        rule.destination
                    )

            case .preserveModifiers:
                newPreservingMappings[
                    rule.source.keyCode
                ] =
                    rule.destination.keyCode
            }

            for override in
                rule.overrides
            {
                newExactMappings[
                    override.source
                ] =
                    override.action
            }
        }

        exactMappings =
            newExactMappings

        preservingMappings =
            newPreservingMappings
    }

    /// Returns the remapping decision for a complete combination.
    ///
    /// Exact rules and overrides always take precedence over
    /// modifier-preserving rules.
    func decision(
        for combination:
            KeyCombination
    ) -> RemapDecision {
        if reservedCombinations.contains(
            combination
        ) {
            return .passThrough
        }

        if let exactAction =
            exactMappings[
                combination
            ]
        {
            return decision(
                for:
                    exactAction
            )
        }

        guard
            let destinationKeyCode =
                preservingMappings[
                    combination.keyCode
                ]
        else {
            return .passThrough
        }

        let destination =
            KeyCombination(
                keyCode:
                    destinationKeyCode,
                modifiers:
                    combination.modifiers
            )

        return replacementDecision(
            for:
                destination
        )
    }

    /// Compatibility overload for code that only supplies a key code.
    func decision(
        for keyCode:
            CGKeyCode
    ) -> RemapDecision {
        decision(
            for:
                KeyCombination(
                    keyCode:
                        keyCode
                )
        )
    }

    private func decision(
        for action:
            RemapAction
    ) -> RemapDecision {
        switch action {
        case .replaceWith(
            let destination
        ):
            return replacementDecision(
                for:
                    destination
            )

        case .passThrough:
            return .passThrough
        }
    }

    private func replacementDecision(
        for destination:
            KeyCombination
    ) -> RemapDecision {
        guard
            !reservedCombinations
                .contains(
                    destination
                )
        else {
            return .passThrough
        }

        return .replaceWith(
            destination
        )
    }
}
