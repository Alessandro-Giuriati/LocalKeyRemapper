//
//  HomeShortcutDraftAssessment.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation

/// Represents the highest-priority interaction between the effective shortcut
/// configuration and the Rules belonging to the proposed active profile.
///
/// Structural shortcut validation remains owned by
/// `GlobalShortcutConfigurationPolicy`.
nonisolated enum HomeShortcutDraftAssessment:
    Equatable
{
    /// No blocking conflict or Preserve Modifiers warning exists.
    case clear

    /// The effective shortcut matches an enabled exact rule or exception.
    case exactConflict(
        profileName:
            String
    )

    /// The effective shortcut is reserved and bypasses one or more enabled
    /// Preserve Modifiers rules.
    case preserveWarning(
        profileName:
            String
    )

    /// Blocking message suitable for the Home editor or profile sheet.
    var blockingMessage:
        String?
    {
        guard
            case let .exactConflict(
                profileName
            ) = self
        else {
            return nil
        }

        return "The proposed shortcut conflicts with an exact mapping in “\(profileName)”. Change the mapping, remove the matching exception, or choose a different shortcut before saving."
    }

    /// Non-blocking guidance suitable for the Home editor or profile sheet.
    var suggestionMessage:
        String?
    {
        guard
            case let .preserveWarning(
                profileName
            ) = self
        else {
            return nil
        }

        return "The application shortcuts remain reserved and bypass matching Preserve Modifiers rules in “\(profileName)”."
    }
}

/// Evaluates shortcut edits against the profile that would become active after
/// Home Save.
///
/// This component performs no persistence, Carbon registration, event
/// processing, keyboard capture, logging, networking, analytics, or telemetry.
nonisolated enum HomeShortcutDraftAssessor {

    /// Assesses a proposed application-wide Default configuration.
    ///
    /// The proposed Default participates in conflict evaluation only when the
    /// proposed active profile uses `Use Default`. An explicit profile override
    /// remains the effective configuration even while the Default is edited.
    static func assessDefaultConfiguration(
        _ proposedDefaultConfiguration:
            RemappingShortcutConfiguration,
        in profilesConfiguration:
            RemappingProfilesConfiguration
    ) throws -> HomeShortcutDraftAssessment {
        guard
            let activeProfile =
                profilesConfiguration
                    .activeProfile
        else {
            throw RemappingProfilesConfigurationValidationError
                .missingActiveProfile(
                    profilesConfiguration
                        .activeProfileID
                )
        }

        let effectiveConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        activeProfile,
                    defaultConfiguration:
                        proposedDefaultConfiguration
                )

        return assessEffectiveConfiguration(
            effectiveConfiguration,
            for:
                activeProfile
        )
    }

    /// Assesses a proposed override for one profile.
    ///
    /// An inactive profile is structurally editable but cannot conflict with
    /// runtime shortcuts because none of its Rules currently run. The proposed
    /// override will be checked later if the same Home draft makes that profile
    /// active.
    static func assessProfileOverride(
        _ proposedOverride:
            RemappingShortcutConfiguration?,
        for profileID:
            UUID,
        defaultConfiguration:
            RemappingShortcutConfiguration,
        in profilesConfiguration:
            RemappingProfilesConfiguration
    ) throws -> HomeShortcutDraftAssessment {
        guard
            let profile =
                profilesConfiguration
                    .profile(
                        id:
                            profileID
                    )
        else {
            throw RemappingProfileRulesAccessError
                .profileNotFound(
                    profileID
                )
        }

        guard
            profilesConfiguration
                .activeProfileID
                == profileID
        else {
            return .clear
        }

        let effectiveConfiguration =
            proposedOverride
                ?? defaultConfiguration

        return assessEffectiveConfiguration(
            effectiveConfiguration,
            for:
                profile
        )
    }

    private static func assessEffectiveConfiguration(
        _ effectiveConfiguration:
            RemappingShortcutConfiguration,
        for profile:
            RemappingProfile
    ) -> HomeShortcutDraftAssessment {
        guard
            !effectiveConfiguration
                .registrations
                .isEmpty
        else {
            return .clear
        }

        let conflicts =
            RemappingShortcutRuleConflictPolicy
                .conflicts(
                    rules:
                        profile.rules,
                    shortcutConfiguration:
                        effectiveConfiguration
                )

        if !conflicts.isEmpty {
            return .exactConflict(
                profileName:
                    profile.name
            )
        }

        let warnings =
            RemappingShortcutRuleConflictPolicy
                .warnings(
                    rules:
                        profile.rules,
                    shortcutConfiguration:
                        effectiveConfiguration
                )

        if !warnings.isEmpty {
            return .preserveWarning(
                profileName:
                    profile.name
            )
        }

        return .clear
    }
}
