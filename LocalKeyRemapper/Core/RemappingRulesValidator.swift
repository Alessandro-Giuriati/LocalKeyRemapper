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

    /// More than one exact rule or override uses the same combination.
    case duplicateSourceCombination(KeyCombination)

    /// More than one modifier-preserving rule uses the same source key.
    case duplicatePreservingSourceKey(CGKeyCode)

    /// Compatibility error for an unmodified identity rule.
    case identicalSourceAndDestination(CGKeyCode)

    /// An exact rule replaces a combination with itself.
    case identicalSourceAndDestinationCombination(
        KeyCombination
    )

    /// Modifier-preserving rules must use unmodified source and
    /// destination keys because incoming modifiers are preserved.
    case invalidModifierPreservingEndpoints

    /// Exact rules cannot contain overrides.
    case overridesRequireModifierPreservingRule

    /// An override must refer to the same physical source key
    /// as its parent modifier-preserving rule.
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
                guard rule.overrides.isEmpty else {
                    throw RemappingRulesValidationError
                        .overridesRequireModifierPreservingRule
                }

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

                for override in rule.overrides {
                    guard
                        override.source.keyCode
                            == rule.source.keyCode
                    else {
                        throw RemappingRulesValidationError
                            .overrideSourceKeyMismatch(
                                expected:
                                    rule.source.keyCode,
                                actual:
                                    override.source.keyCode
                            )
                    }

                    try insertExactSource(
                        override.source,
                        into: &exactSources
                    )

                    if case .replaceWith(
                        let destination
                    ) = override.action {
                        try validateReplacement(
                            source: override.source,
                            destination: destination
                        )
                    }
                }
            }
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
