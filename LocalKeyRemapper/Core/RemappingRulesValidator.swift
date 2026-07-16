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

    /// More than one rule uses the same source key.
    case duplicateSourceKey(CGKeyCode)

    /// A rule maps a key to itself.
    case identicalSourceAndDestination(CGKeyCode)
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
        var sourceKeyCodes = Set<CGKeyCode>()

        for rule in rules {
            let insertionResult = sourceKeyCodes.insert(
                rule.sourceKeyCode
            )

            guard insertionResult.inserted else {
                throw RemappingRulesValidationError
                    .duplicateSourceKey(
                        rule.sourceKeyCode
                    )
            }

            guard
                rule.sourceKeyCode
                    != rule.destinationKeyCode
            else {
                throw RemappingRulesValidationError
                    .identicalSourceAndDestination(
                        rule.sourceKeyCode
                    )
            }
        }
    }
}
