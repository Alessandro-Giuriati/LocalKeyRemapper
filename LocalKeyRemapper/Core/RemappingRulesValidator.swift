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
    /// Describes one active exact source and why it exists.
    private struct ExactSourceRegistration {
        let combination: KeyCombination
        let ownerIndex: Int

        /// True only for the source of a generated reverse rule direction.
        /// Generated reverse exceptions remain overrides of their own parent
        /// Preserve Modifiers direction and therefore use false here.
        let isGeneratedReverseDirection: Bool
    }

    /// Describes one active Preserve Modifiers source and why it exists.
    private struct PreservingSourceRegistration {
        let keyCode: CGKeyCode
        let ownerIndex: Int
        let isGeneratedReverseDirection: Bool
    }

    func validate(
        _ rules: [RemapRule]
    ) throws {
        var exactSources =
            Set<KeyCombination>()

        var exactRegistrationsByKeyCode:
            [CGKeyCode: [ExactSourceRegistration]] = [:]

        var preservingRegistrationsByKeyCode:
            [CGKeyCode: PreservingSourceRegistration] = [:]

        for (
            ownerIndex,
            rule
        ) in rules.enumerated() {
            // Structural validity is independent from runtime activation.
            // A disabled rule must remain complete and internally safe so it
            // can be edited, stored, and re-enabled without carrying malformed
            // endpoints or exceptions.
            try validateDirectionStructure(
                source:
                    rule.source,
                destination:
                    rule.destination,
                matchingMode:
                    rule.matchingMode
            )

            try validateStoredOverrides(
                rule.overrides,
                parentSourceKeyCode:
                    rule.source.keyCode
            )

            if rule.isBidirectional {
                let mirroredOverrides =
                    reverseOverrides(
                        from:
                            rule.overrides,
                        reverseSourceKeyCode:
                            rule.destination.keyCode
                    )

                try validateDirectionStructure(
                    source:
                        rule.destination,
                    destination:
                        rule.source,
                    matchingMode:
                        rule.matchingMode
                )

                try validateStoredOverrides(
                    mirroredOverrides,
                    parentSourceKeyCode:
                        rule.destination.keyCode
                )
            }

            // A disabled rule has no runtime source in either direction.
            // Its forward mapping, generated Reverse mapping, and exceptions
            // therefore cannot conflict with the active configuration.
            guard
                rule.isEnabled
            else {
                continue
            }

            try validateDirection(
                source:
                    rule.source,
                destination:
                    rule.destination,
                matchingMode:
                    rule.matchingMode,
                activeOverrides:
                    rule.overrides,
                ownerIndex:
                    ownerIndex,
                isGeneratedReverseDirection:
                    false,
                exactSources:
                    &exactSources,
                exactRegistrationsByKeyCode:
                    &exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    &preservingRegistrationsByKeyCode
            )

            guard
                rule.isBidirectional
            else {
                continue
            }

            try validateDirection(
                source:
                    rule.destination,
                destination:
                    rule.source,
                matchingMode:
                    rule.matchingMode,
                activeOverrides:
                    reverseOverrides(
                        from:
                            rule.overrides,
                        reverseSourceKeyCode:
                            rule.destination.keyCode
                    ),
                ownerIndex:
                    ownerIndex,
                isGeneratedReverseDirection:
                    true,
                exactSources:
                    &exactSources,
                exactRegistrationsByKeyCode:
                    &exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    &preservingRegistrationsByKeyCode
            )
        }
    }

    /// Validates one stored direction without registering any runtime source.
    ///
    /// This runs for both enabled and disabled rules. Activation controls only
    /// participation in runtime conflicts, not the internal validity of the
    /// stored configuration.
    private func validateDirectionStructure(
        source: KeyCombination,
        destination: KeyCombination,
        matchingMode: RemapMatchingMode
    ) throws {
        switch matchingMode {
        case .exact:
            try validateReplacement(
                source:
                    source,
                destination:
                    destination
            )

        case .preserveModifiers:
            guard
                source.modifiers.isEmpty,
                destination.modifiers.isEmpty
            else {
                throw RemappingRulesValidationError
                    .invalidModifierPreservingEndpoints
            }

            guard
                source.keyCode
                    != destination.keyCode
            else {
                throw RemappingRulesValidationError
                    .identicalSourceAndDestination(
                        source.keyCode
                    )
            }
        }
    }

    /// Validates one active direction exactly as it will be compiled
    /// by the remapping engine.
    private func validateDirection(
        source: KeyCombination,
        destination: KeyCombination,
        matchingMode: RemapMatchingMode,
        activeOverrides: [RemapOverride],
        ownerIndex: Int,
        isGeneratedReverseDirection: Bool,
        exactSources: inout Set<KeyCombination>,
        exactRegistrationsByKeyCode:
            inout [CGKeyCode: [ExactSourceRegistration]],
        preservingRegistrationsByKeyCode:
            inout [CGKeyCode: PreservingSourceRegistration]
    ) throws {
        switch matchingMode {
        case .exact:
            try insertExactSource(
                source,
                registration:
                    ExactSourceRegistration(
                        combination:
                            source,
                        ownerIndex:
                            ownerIndex,
                        isGeneratedReverseDirection:
                            isGeneratedReverseDirection
                    ),
                exactSources:
                    &exactSources,
                exactRegistrationsByKeyCode:
                    &exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    preservingRegistrationsByKeyCode
            )

            try validateReplacement(
                source:
                    source,
                destination:
                    destination
            )

        case .preserveModifiers:
            guard
                source.modifiers.isEmpty,
                destination.modifiers.isEmpty
            else {
                throw RemappingRulesValidationError
                    .invalidModifierPreservingEndpoints
            }

            try insertPreservingSource(
                PreservingSourceRegistration(
                    keyCode:
                        source.keyCode,
                    ownerIndex:
                        ownerIndex,
                    isGeneratedReverseDirection:
                        isGeneratedReverseDirection
                ),
                exactRegistrationsByKeyCode:
                    exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    &preservingRegistrationsByKeyCode
            )

            guard
                source.keyCode
                    != destination.keyCode
            else {
                throw RemappingRulesValidationError
                    .identicalSourceAndDestination(
                        source.keyCode
                    )
            }

            try validateActiveOverrides(
                activeOverrides,
                expectedSourceKeyCode:
                    source.keyCode,
                ownerIndex:
                    ownerIndex,
                exactSources:
                    &exactSources,
                exactRegistrationsByKeyCode:
                    &exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    preservingRegistrationsByKeyCode
            )
        }
    }

    /// Validates persisted exceptions even while their parent rule is Exact.
    private func validateStoredOverrides(
        _ overrides: [RemapOverride],
        parentSourceKeyCode: CGKeyCode
    ) throws {
        for remapOverride in overrides {
            guard
                remapOverride.source.keyCode
                    == parentSourceKeyCode
            else {
                throw RemappingRulesValidationError
                    .overrideSourceKeyMismatch(
                        expected:
                            parentSourceKeyCode,
                        actual:
                            remapOverride.source.keyCode
                    )
            }

            try validateOverrideReplacement(
                remapOverride
            )
        }
    }

    /// Registers enabled overrides as exact sources.
    ///
    /// Cross-mode checks ignore the parent Preserve Modifiers direction when
    /// it belongs to the same rule, because an override is intentionally more
    /// specific than that parent direction.
    private func validateActiveOverrides(
        _ overrides: [RemapOverride],
        expectedSourceKeyCode: CGKeyCode,
        ownerIndex: Int,
        exactSources: inout Set<KeyCombination>,
        exactRegistrationsByKeyCode:
            inout [CGKeyCode: [ExactSourceRegistration]],
        preservingRegistrationsByKeyCode:
            [CGKeyCode: PreservingSourceRegistration]
    ) throws {
        for remapOverride in overrides {
            guard
                remapOverride.source.keyCode
                    == expectedSourceKeyCode
            else {
                throw RemappingRulesValidationError
                    .overrideSourceKeyMismatch(
                        expected:
                            expectedSourceKeyCode,
                        actual:
                            remapOverride.source.keyCode
                    )
            }

            try validateOverrideReplacement(
                remapOverride
            )

            guard
                remapOverride.isEnabled
            else {
                continue
            }

            try insertExactSource(
                remapOverride.source,
                registration:
                    ExactSourceRegistration(
                        combination:
                            remapOverride.source,
                        ownerIndex:
                            ownerIndex,
                        isGeneratedReverseDirection:
                            false
                    ),
                exactSources:
                    &exactSources,
                exactRegistrationsByKeyCode:
                    &exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    preservingRegistrationsByKeyCode
            )
        }
    }

    private func validateOverrideReplacement(
        _ remapOverride: RemapOverride
    ) throws {
        guard
            case .replaceWith(
                let destination
            ) = remapOverride.action
        else {
            return
        }

        try validateReplacement(
            source:
                remapOverride.source,
            destination:
                destination
        )
    }

    /// Inserts an exact source and rejects any active Preserve Modifiers
    /// direction owned by another rule on the same physical key.
    private func insertExactSource(
        _ source: KeyCombination,
        registration: ExactSourceRegistration,
        exactSources: inout Set<KeyCombination>,
        exactRegistrationsByKeyCode:
            inout [CGKeyCode: [ExactSourceRegistration]],
        preservingRegistrationsByKeyCode:
            [CGKeyCode: PreservingSourceRegistration]
    ) throws {
        let insertionResult =
            exactSources.insert(
                source
            )

        guard
            insertionResult.inserted
        else {
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

        if let preservingRegistration =
            preservingRegistrationsByKeyCode[
                source.keyCode
            ],
           preservingRegistration.ownerIndex
                != registration.ownerIndex
        {
            throw RemappingRulesValidationError
                .duplicateSourceCombination(
                    source
                )
        }

        exactRegistrationsByKeyCode[
            source.keyCode,
            default:
                []
        ].append(
            registration
        )
    }

    /// Inserts a Preserve Modifiers source and rejects every active exact
    /// source owned by another rule on the same physical key.
    private func insertPreservingSource(
        _ registration: PreservingSourceRegistration,
        exactRegistrationsByKeyCode:
            [CGKeyCode: [ExactSourceRegistration]],
        preservingRegistrationsByKeyCode:
            inout [CGKeyCode: PreservingSourceRegistration]
    ) throws {
        if preservingRegistrationsByKeyCode[
            registration.keyCode
        ] != nil {
            throw RemappingRulesValidationError
                .duplicatePreservingSourceKey(
                    registration.keyCode
                )
        }

        if let exactRegistrations =
            exactRegistrationsByKeyCode[
                registration.keyCode
            ]
        {
            for exactRegistration in exactRegistrations
            where exactRegistration.ownerIndex
                != registration.ownerIndex
            {
                throw RemappingRulesValidationError
                    .duplicateSourceCombination(
                        exactRegistration.combination
                    )
            }
        }

        preservingRegistrationsByKeyCode[
            registration.keyCode
        ] = registration
    }

    /// Derives the exceptions used by the reverse Preserve Modifiers
    /// direction. The physical source key changes, while modifiers, action,
    /// and enabled state remain unchanged.
    private func reverseOverrides(
        from overrides: [RemapOverride],
        reverseSourceKeyCode: CGKeyCode
    ) -> [RemapOverride] {
        overrides.map {
            remapOverride in

            RemapOverride(
                source:
                    KeyCombination(
                        keyCode:
                            reverseSourceKeyCode,
                        modifiers:
                            remapOverride.source.modifiers
                    ),
                action:
                    remapOverride.action,
                isEnabled:
                    remapOverride.isEnabled
            )
        }
    }

    private func validateReplacement(
        source: KeyCombination,
        destination: KeyCombination
    ) throws {
        guard
            source != destination
        else {
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
