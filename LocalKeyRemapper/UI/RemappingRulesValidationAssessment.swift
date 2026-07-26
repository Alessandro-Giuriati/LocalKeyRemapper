//
//  RemappingRulesValidationAssessment.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/23/26.
//

import CoreGraphics
import Foundation

/// Evaluates editor validation without changing rules, presentation state,
/// persistence, dirty state, sorting, filtering, or Undo/Redo history.
nonisolated struct RemappingRulesValidationAssessment:
    Equatable
{
    enum Issue:
        Equatable,
        Hashable
    {
        case incompleteRule
        case duplicateSource
        case identicalSourceAndDestination

        var message: String {
            switch self {
            case .incompleteRule:
                return "Choose both Source and Destination before saving."

            case .duplicateSource:
                return "This source or generated reverse source conflicts with another active rule or enabled exception."

            case .identicalSourceAndDestination:
                return "Source and Destination cannot be identical."
            }
        }

        var priority: Int {
            switch self {
            case .duplicateSource:
                return 0

            case .identicalSourceAndDestination:
                return 1

            case .incompleteRule:
                return 2
            }
        }
    }

    /// Describes one active exact source and why it exists.
    private struct ExactSourceRegistration {
        let combination: KeyCombination
        let ownerID: UUID

        /// True only for the source of a generated reverse rule direction.
        /// Generated reverse exceptions remain exact overrides of their own
        /// Preserve Modifiers direction, matching the central validator.
        let isGeneratedReverseDirection: Bool
    }

    /// Describes one active Preserve Modifiers physical source key.
    private struct PreservingSourceRegistration {
        let keyCode: CGKeyCode
        let ownerID: UUID
        let isGeneratedReverseDirection: Bool
    }

    let issuesByItemID:
        [UUID: [Issue]]

    var invalidItemIDs:
        Set<UUID>
    {
        Set(
            issuesByItemID.keys
        )
    }

    var hasIssues: Bool {
        !issuesByItemID.isEmpty
    }

    var primaryIssue:
        Issue?
    {
        issuesByItemID
            .values
            .flatMap {
                $0
            }
            .min {
                $0.priority
                    < $1.priority
            }
    }

    init(
        items:
            [RemappingRuleEditorItem]
    ) {
        var issuesByItemID:
            [UUID: Set<Issue>] = [:]

        var exactRegistrationsByCombination:
            [KeyCombination: [ExactSourceRegistration]] = [:]

        var exactRegistrationsByKeyCode:
            [CGKeyCode: [ExactSourceRegistration]] = [:]

        var preservingRegistrationsByKeyCode:
            [CGKeyCode: [PreservingSourceRegistration]] = [:]

        for item in items {
            guard
                let rule = item.rule
            else {
                Self.insert(
                    .incompleteRule,
                    for:
                        item.id,
                    into:
                        &issuesByItemID
                )

                continue
            }

            Self.assessStoredOverrides(
                rule.overrides,
                ownerID:
                    item.id,
                issuesByItemID:
                    &issuesByItemID
            )

            Self.registerDirection(
                source:
                    rule.source,
                destination:
                    rule.destination,
                matchingMode:
                    rule.matchingMode,
                activeOverrides:
                    rule.overrides,
                ownerID:
                    item.id,
                isGeneratedReverseDirection:
                    false,
                exactRegistrationsByCombination:
                    &exactRegistrationsByCombination,
                exactRegistrationsByKeyCode:
                    &exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    &preservingRegistrationsByKeyCode,
                issuesByItemID:
                    &issuesByItemID
            )

            guard
                rule.isBidirectional
            else {
                continue
            }

            Self.registerDirection(
                source:
                    rule.destination,
                destination:
                    rule.source,
                matchingMode:
                    rule.matchingMode,
                activeOverrides:
                    Self.reverseOverrides(
                        from:
                            rule.overrides,
                        reverseSourceKeyCode:
                            rule.destination.keyCode
                    ),
                ownerID:
                    item.id,
                isGeneratedReverseDirection:
                    true,
                exactRegistrationsByCombination:
                    &exactRegistrationsByCombination,
                exactRegistrationsByKeyCode:
                    &exactRegistrationsByKeyCode,
                preservingRegistrationsByKeyCode:
                    &preservingRegistrationsByKeyCode,
                issuesByItemID:
                    &issuesByItemID
            )
        }

        Self.markDuplicateExactSources(
            exactRegistrationsByCombination,
            issuesByItemID:
                &issuesByItemID
        )

        Self.markDuplicatePreservingSources(
            preservingRegistrationsByKeyCode,
            issuesByItemID:
                &issuesByItemID
        )

        Self.markReverseCrossModeConflicts(
            exactRegistrationsByKeyCode:
                exactRegistrationsByKeyCode,
            preservingRegistrationsByKeyCode:
                preservingRegistrationsByKeyCode,
            issuesByItemID:
                &issuesByItemID
        )

        self.issuesByItemID =
            issuesByItemID.mapValues {
                issues in

                issues.sorted {
                    $0.priority
                        < $1.priority
                }
            }
    }

    /// Registers one active rule direction exactly as the runtime engine and
    /// central validator interpret it.
    private static func registerDirection(
        source:
            KeyCombination,
        destination:
            KeyCombination,
        matchingMode:
            RemapMatchingMode,
        activeOverrides:
            [RemapOverride],
        ownerID:
            UUID,
        isGeneratedReverseDirection:
            Bool,
        exactRegistrationsByCombination:
            inout [KeyCombination: [ExactSourceRegistration]],
        exactRegistrationsByKeyCode:
            inout [CGKeyCode: [ExactSourceRegistration]],
        preservingRegistrationsByKeyCode:
            inout [CGKeyCode: [PreservingSourceRegistration]],
        issuesByItemID:
            inout [UUID: Set<Issue>]
    ) {
        switch matchingMode {
        case .exact:
            let registration =
                ExactSourceRegistration(
                    combination:
                        source,
                    ownerID:
                        ownerID,
                    isGeneratedReverseDirection:
                        isGeneratedReverseDirection
                )

            exactRegistrationsByCombination[
                source,
                default:
                    []
            ].append(
                registration
            )

            exactRegistrationsByKeyCode[
                source.keyCode,
                default:
                    []
            ].append(
                registration
            )

            if source == destination {
                insert(
                    .identicalSourceAndDestination,
                    for:
                        ownerID,
                    into:
                        &issuesByItemID
                )
            }

        case .preserveModifiers:
            let registration =
                PreservingSourceRegistration(
                    keyCode:
                        source.keyCode,
                    ownerID:
                        ownerID,
                    isGeneratedReverseDirection:
                        isGeneratedReverseDirection
                )

            preservingRegistrationsByKeyCode[
                source.keyCode,
                default:
                    []
            ].append(
                registration
            )

            if source.keyCode == destination.keyCode {
                insert(
                    .identicalSourceAndDestination,
                    for:
                        ownerID,
                    into:
                        &issuesByItemID
                )
            }

            for remapOverride in activeOverrides
            where remapOverride.isEnabled {
                let overrideRegistration =
                    ExactSourceRegistration(
                        combination:
                            remapOverride.source,
                        ownerID:
                            ownerID,
                        isGeneratedReverseDirection:
                            false
                    )

                exactRegistrationsByCombination[
                    remapOverride.source,
                    default:
                        []
                ].append(
                    overrideRegistration
                )

                exactRegistrationsByKeyCode[
                    remapOverride.source.keyCode,
                    default:
                        []
                ].append(
                    overrideRegistration
                )

                assessOverrideReplacement(
                    remapOverride,
                    ownerID:
                        ownerID,
                    issuesByItemID:
                        &issuesByItemID
                )
            }
        }
    }

    /// Exact sources always conflict when the complete combination is equal.
    /// This includes generated reverse Exact directions and active exceptions.
    private static func markDuplicateExactSources(
        _ registrationsByCombination:
            [KeyCombination: [ExactSourceRegistration]],
        issuesByItemID:
            inout [UUID: Set<Issue>]
    ) {
        for registrations in registrationsByCombination.values
        where registrations.count > 1 {
            for registration in registrations {
                insert(
                    .duplicateSource,
                    for:
                        registration.ownerID,
                    into:
                        &issuesByItemID
                )
            }
        }
    }

    /// Preserve Modifiers sources always conflict when they use the same
    /// physical source key.
    private static func markDuplicatePreservingSources(
        _ registrationsByKeyCode:
            [CGKeyCode: [PreservingSourceRegistration]],
        issuesByItemID:
            inout [UUID: Set<Issue>]
    ) {
        for registrations in registrationsByKeyCode.values
        where registrations.count > 1 {
            for registration in registrations {
                insert(
                    .duplicateSource,
                    for:
                        registration.ownerID,
                    into:
                        &issuesByItemID
                )
            }
        }
    }

    /// Exact and Preserve Modifiers rules normally coexist because exact
    /// combinations intentionally take precedence.
    ///
    /// When either source was generated by Reverse, however, allowing the
    /// overlap would make the generated direction silently depend on rule
    /// precedence. The central validator rejects that ambiguity, so the live
    /// assessment marks both owning rows as invalid as well.
    private static func markReverseCrossModeConflicts(
        exactRegistrationsByKeyCode:
            [CGKeyCode: [ExactSourceRegistration]],
        preservingRegistrationsByKeyCode:
            [CGKeyCode: [PreservingSourceRegistration]],
        issuesByItemID:
            inout [UUID: Set<Issue>]
    ) {
        for (
            keyCode,
            exactRegistrations
        ) in exactRegistrationsByKeyCode {
            guard
                let preservingRegistrations =
                    preservingRegistrationsByKeyCode[
                        keyCode
                    ]
            else {
                continue
            }

            for exactRegistration in exactRegistrations {
                for preservingRegistration in preservingRegistrations
                where exactRegistration.ownerID
                    != preservingRegistration.ownerID
                    && (
                        exactRegistration
                            .isGeneratedReverseDirection
                        || preservingRegistration
                            .isGeneratedReverseDirection
                    )
                {
                    insert(
                        .duplicateSource,
                        for:
                            exactRegistration.ownerID,
                        into:
                            &issuesByItemID
                    )

                    insert(
                        .duplicateSource,
                        for:
                            preservingRegistration.ownerID,
                        into:
                            &issuesByItemID
                    )
                }
            }
        }
    }

    /// Stored exceptions remain part of the persistent configuration even
    /// while their parent rule is Exact Only.
    private static func assessStoredOverrides(
        _ overrides:
            [RemapOverride],
        ownerID:
            UUID,
        issuesByItemID:
            inout [UUID: Set<Issue>]
    ) {
        for remapOverride in overrides {
            assessOverrideReplacement(
                remapOverride,
                ownerID:
                    ownerID,
                issuesByItemID:
                    &issuesByItemID
            )
        }
    }

    private static func assessOverrideReplacement(
        _ remapOverride:
            RemapOverride,
        ownerID:
            UUID,
        issuesByItemID:
            inout [UUID: Set<Issue>]
    ) {
        guard
            case .replaceWith(
                let destination
            ) = remapOverride.action,
            remapOverride.source == destination
        else {
            return
        }

        insert(
            .identicalSourceAndDestination,
            for:
                ownerID,
            into:
                &issuesByItemID
        )
    }

    /// Derives the exceptions used by the reverse Preserve Modifiers
    /// direction. Only the physical source key changes.
    private static func reverseOverrides(
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
                            remapOverride.source.modifiers
                    ),
                action:
                    remapOverride.action,
                isEnabled:
                    remapOverride.isEnabled
            )
        }
    }

    func affectsRule(
        id:
            UUID
    ) -> Bool {
        issuesByItemID[
            id
        ]?.isEmpty
            == false
    }

    func issues(
        forRuleID ruleID:
            UUID
    ) -> [Issue] {
        issuesByItemID[
            ruleID
        ] ?? []
    }

    func message(
        forRuleID ruleID:
            UUID
    ) -> String? {
        let messages =
            issues(
                forRuleID:
                    ruleID
            )
            .map(
                \.message
            )

        guard
            !messages.isEmpty
        else {
            return nil
        }

        return messages.joined(
            separator:
                "\n"
        )
    }

    private static func insert(
        _ issue:
            Issue,
        for itemID:
            UUID,
        into issuesByItemID:
            inout [UUID: Set<Issue>]
    ) {
        issuesByItemID[
            itemID,
            default:
                []
        ].insert(
            issue
        )
    }
}
