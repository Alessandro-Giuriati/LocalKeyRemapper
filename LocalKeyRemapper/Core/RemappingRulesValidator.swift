//
//  RemappingRulesValidator.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import CoreGraphics

/// Represents a validation error found in a collection
/// of keyboard remapping rules.
nonisolated enum RemappingRulesValidationError:
    Error,
    Equatable
{
    /// Compatibility error for duplicate exact rules without modifiers.
    case duplicateSourceKey(CGKeyCode)

    /// More than one active exact rule or override uses the same combination.
    case duplicateSourceCombination(KeyCombination)

    /// More than one modifier-preserving rule uses the same source key.
    case duplicatePreservingSourceKey(CGKeyCode)

    /// Compatibility error for an unmodified identity rule.
    case identicalSourceAndDestination(CGKeyCode)

    /// An exact rule or stored override replaces a combination with itself.
    case identicalSourceAndDestinationCombination(
        KeyCombination
    )

    /// Modifier-preserving rules must use unmodified source and
    /// destination keys because incoming modifiers are preserved.
    case invalidModifierPreservingEndpoints

    /// Retained for source compatibility with older callers.
    /// Exact rules may now keep stored overrides, so the validator
    /// no longer throws this error.
    case overridesRequireModifierPreservingRule

    /// An override must refer to the same physical source key
    /// as its parent rule.
    case overrideSourceKeyMismatch(
        expected: CGKeyCode,
        actual: CGKeyCode
    )
}

/// Defines the validation operation required before
/// remapping rules are stored or loaded into the engine.
nonisolated protocol RemappingRulesValidating {

    /// Validates the complete collection of remapping rules.
    func validate(
        _ rules: [RemapRule]
    ) throws
}

/// Validates keyboard remapping rules without accessing
/// storage, the user interface, or keyboard events.
nonisolated struct RemappingRulesValidator:
    RemappingRulesValidating
{
    func validate(
        _ rules: [RemapRule]
    ) throws {
        var exactSources =
            Set<KeyCombination>()

        var preservingSourceKeyCodes =
            Set<CGKeyCode>()

        for rule in rules {
            switch rule.matchingMode {
            case .exact:
                try insertExactSource(
                    rule.source,
                    into: &exactSources
                )

                try validateReplacement(
                    source: rule.source,
                    destination: rule.destination
                )

            case .preserveModifiers:
                guard
                    rule.source.modifiers.isEmpty,
                    rule.destination.modifiers.isEmpty
                else {
                    throw RemappingRulesValidationError
                        .invalidModifierPreservingEndpoints
                }

                let insertionResult =
                    preservingSourceKeyCodes.insert(
                        rule.source.keyCode
                    )

                guard insertionResult.inserted else {
                    throw RemappingRulesValidationError
                        .duplicatePreservingSourceKey(
                            rule.source.keyCode
                        )
                }

                guard
                    rule.source.keyCode
                        != rule.destination.keyCode
                else {
                    throw RemappingRulesValidationError
                        .identicalSourceAndDestination(
                            rule.source.keyCode
                        )
                }
            }

            try validateStoredOverrides(
                rule.overrides,
                parentSourceKeyCode: rule.source.keyCode,
                areActive:
                    rule.matchingMode == .preserveModifiers,
                exactSources: &exactSources
            )
        }
    }

    private func validateStoredOverrides(
        _ overrides: [RemapOverride],
        parentSourceKeyCode: CGKeyCode,
        areActive: Bool,
        exactSources: inout Set<KeyCombination>
    ) throws {
        for override in overrides {
            guard
                override.source.keyCode
                    == parentSourceKeyCode
            else {
                throw RemappingRulesValidationError
                    .overrideSourceKeyMismatch(
                        expected:
                            parentSourceKeyCode,
                        actual:
                            override.source.keyCode
                    )
            }

            if case .replaceWith(
                let destination
            ) = override.action {
                try validateReplacement(
                    source: override.source,
                    destination: destination
                )
            }

            guard areActive,
                  override.isEnabled else {
                continue
            }

            try insertExactSource(
                override.source,
                into: &exactSources
            )
        }
    }

    private func insertExactSource(
        _ source: KeyCombination,
        into sources:
            inout Set<KeyCombination>
    ) throws {
        let insertionResult =
            sources.insert(source)

        guard insertionResult.inserted else {
            if source.modifiers.isEmpty {
                throw RemappingRulesValidationError
                    .duplicateSourceKey(
                        source.keyCode
                    )
            }

            throw RemappingRulesValidationError
                .duplicateSourceCombination(
                    source
                )
        }
    }

    private func validateReplacement(
        source: KeyCombination,
        destination: KeyCombination
    ) throws {
        guard source != destination else {
            if source.modifiers.isEmpty {
                throw RemappingRulesValidationError
                    .identicalSourceAndDestination(
                        source.keyCode
                    )
            }

            throw RemappingRulesValidationError
                .identicalSourceAndDestinationCombination(
                    source
                )
        }
    }
}
