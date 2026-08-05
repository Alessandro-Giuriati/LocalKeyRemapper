//
//  ProfileActivationShortcutConflict.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 8/5/26.
//

import Foundation

/// Identifies whether a failed profile activation used the application-wide
/// default shortcut configuration or a profile-specific override.
nonisolated enum ProfileActivationShortcutSource:
    Equatable
{
    case defaultGlobal
    case profileSpecific
}

/// Adds profile context to a blocking rule/shortcut conflict detected while
/// another persisted profile is being activated.
///
/// The underlying conflict remains unchanged and reusable by the validation
/// layer. This value records only the target profile and the origin of its
/// effective shortcut so every interface can explain the failed activation
/// accurately.
nonisolated struct ProfileActivationShortcutConflict:
    Error,
    Equatable
{
    let profileID:
        UUID

    let persistedProfileName:
        String

    let shortcutSource:
        ProfileActivationShortcutSource

    let conflict:
        RemappingShortcutRuleConflict

    init(
        profile:
            RemappingProfile,
        conflict:
            RemappingShortcutRuleConflict
    ) {
        profileID =
            profile.id

        persistedProfileName =
            profile.name

        shortcutSource =
            profile.shortcutConfigurationOverride == nil
                ? .defaultGlobal
                : .profileSpecific

        self.conflict =
            conflict
    }
}
