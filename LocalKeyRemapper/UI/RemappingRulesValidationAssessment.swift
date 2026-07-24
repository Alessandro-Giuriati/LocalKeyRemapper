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
                return "This source conflicts with another active rule or enabled exception."

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

        var exactOwners:
            [KeyCombination: [UUID]] = [:]

        var preservingOwners:
            [CGKeyCode: [UUID]] = [:]

        for item in items {
            guard
                let rule =
                    item.rule
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

            switch rule.matchingMode {
            case .exact:
                exactOwners[
                    rule.source,
                    default:
                        []
                ].append(
                    item.id
                )

                if rule.source
                    == rule.destination
                {
                    Self.insert(
                        .identicalSourceAndDestination,
                        for:
                            item.id,
                        into:
                            &issuesByItemID
                    )
                }

            case .preserveModifiers:
                preservingOwners[
                    rule.source.keyCode,
                    default:
                        []
                ].append(
                    item.id
                )

                if rule.source.keyCode
                    == rule.destination.keyCode
                {
                    Self.insert(
                        .identicalSourceAndDestination,
                        for:
                            item.id,
                        into:
                            &issuesByItemID
                    )
                }

                for remapOverride in rule.overrides
                where remapOverride.isEnabled {
                    exactOwners[
                        remapOverride.source,
                        default:
                            []
                    ].append(
                        item.id
                    )

                    if case .replaceWith(
                        let destination
                    ) = remapOverride.action,
                       remapOverride.source
                        == destination
                    {
                        Self.insert(
                            .identicalSourceAndDestination,
                            for:
                                item.id,
                            into:
                                &issuesByItemID
                        )
                    }
                }
            }
        }

        for owners in exactOwners.values
        where owners.count > 1 {
            for ownerID in owners {
                Self.insert(
                    .duplicateSource,
                    for:
                        ownerID,
                    into:
                        &issuesByItemID
                )
            }
        }

        for owners in preservingOwners.values
        where owners.count > 1 {
            for ownerID in owners {
                Self.insert(
                    .duplicateSource,
                    for:
                        ownerID,
                    into:
                        &issuesByItemID
                )
            }
        }

        self.issuesByItemID =
            issuesByItemID.mapValues {
                issues in

                issues.sorted {
                    $0.priority
                        < $1.priority
                }
            }
    }

    func affectsRule(
        id: UUID
    ) -> Bool {
        issuesByItemID[
            id
        ]?.isEmpty
            == false
    }

    func issues(
        forRuleID ruleID: UUID
    ) -> [Issue] {
        issuesByItemID[
            ruleID
        ] ?? []
    }

    func message(
        forRuleID ruleID: UUID
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
        _ issue: Issue,
        for itemID: UUID,
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
