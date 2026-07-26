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

    /// Exact combination rules and active exact overrides.
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
    /// Each persisted rule is compiled into one forward direction and,
    /// when enabled, one derived reverse direction.
    ///
    /// The reverse direction is never persisted as a separate rule.
    /// Preparing both directions here keeps keyboard-event processing
    /// limited to constant-time dictionary lookups.
    func replaceRules(
        _ rules:
            [RemapRule]
    ) {
        var newExactMappings:
            [KeyCombination: RemapAction] = [:]

        var newPreservingMappings:
            [CGKeyCode: CGKeyCode] = [:]

        for rule in rules {
            compileDirection(
                source:
                    rule.source,
                destination:
                    rule.destination,
                matchingMode:
                    rule.matchingMode,
                overrides:
                    rule.overrides,
                exactMappings:
                    &newExactMappings,
                preservingMappings:
                    &newPreservingMappings
            )

            guard
                rule.isBidirectional
            else {
                continue
            }

            compileDirection(
                source:
                    rule.destination,
                destination:
                    rule.source,
                matchingMode:
                    rule.matchingMode,
                overrides:
                    reverseOverrides(
                        from:
                            rule.overrides,
                        reverseSourceKeyCode:
                            rule.destination
                                .keyCode
                    ),
                exactMappings:
                    &newExactMappings,
                preservingMappings:
                    &newPreservingMappings
            )
        }

        exactMappings =
            newExactMappings

        preservingMappings =
            newPreservingMappings
    }

    /// Compiles one active direction of a rule.
    ///
    /// For Exact Only rules, the complete source combination maps to the
    /// complete destination combination.
    ///
    /// For Preserve Modifiers rules, the source physical key maps to the
    /// destination physical key while active exact overrides are compiled
    /// separately and retain precedence.
    private func compileDirection(
        source:
            KeyCombination,
        destination:
            KeyCombination,
        matchingMode:
            RemapMatchingMode,
        overrides:
            [RemapOverride],
        exactMappings:
            inout [KeyCombination: RemapAction],
        preservingMappings:
            inout [CGKeyCode: CGKeyCode]
    ) {
        switch matchingMode {
        case .exact:
            exactMappings[
                source
            ] =
                .replaceWith(
                    destination
                )

        case .preserveModifiers:
            preservingMappings[
                source.keyCode
            ] =
                destination.keyCode

            for remapOverride in overrides
            where remapOverride.isEnabled {
                exactMappings[
                    remapOverride.source
                ] =
                    remapOverride.action
            }
        }
    }

    /// Derives the exceptions used by the reverse direction.
    ///
    /// An exception belongs to the physical source key of its direction.
    /// Therefore, when V -> W becomes V <-> W, an exception whose source is
    /// Command + V is mirrored as Command + W.
    ///
    /// Its modifiers, enabled state, and configured action remain unchanged.
    /// No second exception is saved or exposed to the user.
    private func reverseOverrides(
        from overrides:
            [RemapOverride],
        reverseSourceKeyCode:
            CGKeyCode
    ) -> [RemapOverride] {
        overrides.map {
            remapOverride in

            RemapOverride(
                source:
                    KeyCombination(
                        keyCode:
                            reverseSourceKeyCode,
                        modifiers:
                            remapOverride
                                .source
                                .modifiers
                    ),
                action:
                    remapOverride
                        .action,
                isEnabled:
                    remapOverride
                        .isEnabled
            )
        }
    }

    /// Returns the remapping decision for a complete combination.
    ///
    /// Exact rules and active overrides always take precedence over
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
