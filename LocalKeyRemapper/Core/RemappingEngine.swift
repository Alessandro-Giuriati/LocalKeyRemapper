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

    init(rules: [RemapRule] = []) {
        replaceRules(rules)
    }

    /// Replaces all currently loaded remapping rules.
    ///
    /// Rules are compiled into dictionaries before keyboard events
    /// are processed, keeping event-time work minimal.
    func replaceRules(
        _ rules: [RemapRule]
    ) {
        var newExactMappings:
            [KeyCombination: RemapAction] = [:]

        var newPreservingMappings:
            [CGKeyCode: CGKeyCode] = [:]

        for rule in rules {
            switch rule.matchingMode {
            case .exact:
                newExactMappings[rule.source] =
                    .replaceWith(rule.destination)

            case .preserveModifiers:
                newPreservingMappings[
                    rule.source.keyCode
                ] = rule.destination.keyCode
            }

            for override in rule.overrides {
                newExactMappings[override.source] =
                    override.action
            }
        }

        exactMappings = newExactMappings
        preservingMappings = newPreservingMappings
    }

    /// Returns the remapping decision for a complete combination.
    ///
    /// Exact rules and overrides always take precedence over
    /// modifier-preserving rules.
    func decision(
        for combination: KeyCombination
    ) -> RemapDecision {
        if let exactAction =
            exactMappings[combination]
        {
            return decision(
                for: exactAction
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

        return .replaceWith(
            KeyCombination(
                keyCode: destinationKeyCode,
                modifiers: combination.modifiers
            )
        )
    }

    /// Compatibility overload for code that only supplies a key code.
    func decision(
        for keyCode: CGKeyCode
    ) -> RemapDecision {
        decision(
            for: KeyCombination(
                keyCode: keyCode
            )
        )
    }

    private func decision(
        for action: RemapAction
    ) -> RemapDecision {
        switch action {
        case .replaceWith(let destination):
            return .replaceWith(destination)

        case .passThrough:
            return .passThrough
        }
    }
}
