//
//  HomeConfigurationSaveTransaction.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import Foundation

/// Represents a failure to restore the previous profiles payload after a later
/// part of the unified Home transaction failed.
nonisolated enum HomeConfigurationSaveTransactionError:
    Error,
    Equatable
{
    case profileRollbackFailed
}

/// Describes the normalized state committed by one unified Home Save.
nonisolated struct HomeConfigurationSaveTransactionResult:
    Equatable
{
    let committedSnapshot:
        HomeConfigurationSnapshot

    let previousProfilesConfiguration:
        RemappingProfilesConfiguration

    let previousShortcutConfiguration:
        RemappingShortcutConfiguration

    /// Indicates whether the application-wide default changed.
    var shortcutConfigurationChanged:
        Bool
    {
        previousShortcutConfiguration
            != committedSnapshot
                .shortcutConfiguration
    }

    var profilesChanged:
        Bool
    {
        previousProfilesConfiguration
            != committedSnapshot
                .profilesConfiguration
    }

    /// Indicates whether the shortcut configuration registered with Carbon
    /// changed, including changes caused by:
    ///
    /// - selecting another active profile;
    /// - changing the active profile's override;
    /// - changing the default used by an active Use Default profile.
    var effectiveShortcutConfigurationChanged:
        Bool
    {
        guard
            let previousActiveProfile =
                previousProfilesConfiguration
                    .activeProfile,
            let committedActiveProfile =
                committedSnapshot
                    .activeProfile
        else {
            return true
        }

        let previousEffectiveConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        previousActiveProfile,
                    defaultConfiguration:
                        previousShortcutConfiguration
                )

        let committedEffectiveConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        committedActiveProfile,
                    defaultConfiguration:
                        committedSnapshot
                            .shortcutConfiguration
                )

        return previousEffectiveConfiguration
            != committedEffectiveConfiguration
    }
}

/// Commits every setting owned by the Home window as one coordinated operation.
///
/// Profiles are persisted before the effective shortcut is registered so
/// shortcut validation observes the proposed active profile and its latest
/// rules. If registration or application-preference persistence fails, the
/// previous profiles payload and effective shortcut are restored.
///
/// Runtime rules are replaced only after every persistence step succeeds.
@MainActor
final class HomeConfigurationSaveTransaction {

    private let profilesStore:
        RemappingProfilesStore

    private let profilesValidator:
        RemappingProfilesConfigurationValidating

    private let rulesValidator:
        RemappingRulesValidating

    private let appPreferencesController:
        AppPreferencesControlling

    private let globalShortcutController:
        GlobalShortcutController

    private let activeRulesApplyHandler:
        ([RemapRule]) -> Void

    init(
        profilesStore:
            RemappingProfilesStore,
        profilesValidator:
            RemappingProfilesConfigurationValidating,
        rulesValidator:
            RemappingRulesValidating,
        appPreferencesController:
            AppPreferencesControlling,
        globalShortcutController:
            GlobalShortcutController,
        activeRulesApplyHandler:
            @escaping ([RemapRule]) -> Void
    ) {
        self.profilesStore =
            profilesStore

        self.profilesValidator =
            profilesValidator

        self.rulesValidator =
            rulesValidator

        self.appPreferencesController =
            appPreferencesController

        self.globalShortcutController =
            globalShortcutController

        self.activeRulesApplyHandler =
            activeRulesApplyHandler
    }

    /// Validates, persists, and applies one complete Home draft.
    ///
    /// The returned snapshot contains normalized profile names and the actual
    /// application preferences held after the successful transaction.
    func commit(
        _ draft:
            HomeConfigurationSnapshot
    ) throws -> HomeConfigurationSaveTransactionResult {
        let previousProfilesConfiguration =
            try profilesStore
                .loadConfiguration()

        let previousDefaultConfiguration =
            appPreferencesController
                .preferences
                .shortcutConfiguration

        guard
            let previousActiveProfile =
                previousProfilesConfiguration
                    .activeProfile
        else {
            throw RemappingProfilesConfigurationValidationError
                .missingActiveProfile(
                    previousProfilesConfiguration
                        .activeProfileID
                )
        }

        let previousEffectiveConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        previousActiveProfile,
                    defaultConfiguration:
                        previousDefaultConfiguration
                )

        let mergedProfilesConfiguration =
            HomeProfilesConfigurationMerger
                .merging(
                    homeDraft:
                        draft.profilesConfiguration,
                    persisted:
                        previousProfilesConfiguration
                )

        let normalizedProfilesConfiguration =
            try profilesValidator
                .normalizedConfiguration(
                    mergedProfilesConfiguration
                )

        guard
            let activeProfile =
                normalizedProfilesConfiguration
                    .activeProfile
        else {
            throw RemappingProfilesConfigurationValidationError
                .missingActiveProfile(
                    normalizedProfilesConfiguration
                        .activeProfileID
                )
        }

        let proposedEffectiveConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        activeProfile,
                    defaultConfiguration:
                        draft.shortcutConfiguration
                )

        try validateRulesAndShortcuts(
            profilesConfiguration:
                normalizedProfilesConfiguration,
            activeProfile:
                activeProfile,
            defaultShortcutConfiguration:
                draft.shortcutConfiguration,
            effectiveShortcutConfiguration:
                proposedEffectiveConfiguration
        )

        let profilesChanged =
            normalizedProfilesConfiguration
                != previousProfilesConfiguration

        var didPersistProfiles =
            false

        do {
            if profilesChanged {
                try profilesStore
                    .saveConfiguration(
                        normalizedProfilesConfiguration
                    )

                didPersistProfiles =
                    true
            }

            try globalShortcutController
                .applyConfiguration(
                    defaultConfiguration:
                        draft.shortcutConfiguration,
                    effectiveConfiguration:
                        proposedEffectiveConfiguration,
                    previousEffectiveConfiguration:
                        previousEffectiveConfiguration,
                    persistingWith: {
                        [appPreferencesController] in

                        try appPreferencesController
                            .setHomeConfiguration(
                                launchBehavior:
                                    draft.launchBehavior,
                                shortcutConfiguration:
                                    draft.shortcutConfiguration
                            )
                    }
                )
        } catch {
            if didPersistProfiles {
                do {
                    try profilesStore
                        .saveConfiguration(
                            previousProfilesConfiguration
                        )
                } catch {
                    throw HomeConfigurationSaveTransactionError
                        .profileRollbackFailed
                }
            }

            throw error
        }

        // This remains the final state-changing operation. It cannot make a
        // partially persisted Home draft active.
        activeRulesApplyHandler(
            activeProfile.rules
        )

        let committedSnapshot =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    normalizedProfilesConfiguration,
                launchBehavior:
                    appPreferencesController
                        .preferences
                        .launchBehavior,
                shortcutConfiguration:
                    appPreferencesController
                        .preferences
                        .shortcutConfiguration
            )

        return HomeConfigurationSaveTransactionResult(
            committedSnapshot:
                committedSnapshot,
            previousProfilesConfiguration:
                previousProfilesConfiguration,
            previousShortcutConfiguration:
                previousDefaultConfiguration
        )
    }

    /// Applies every blocking rule and shortcut policy before storage changes.
    ///
    /// Every profile's Rules and explicit shortcut override are structurally
    /// validated. Shortcut conflicts are evaluated only between the active
    /// profile's Rules and its effective shortcut configuration.
    private func validateRulesAndShortcuts(
        profilesConfiguration:
            RemappingProfilesConfiguration,
        activeProfile:
            RemappingProfile,
        defaultShortcutConfiguration:
            RemappingShortcutConfiguration,
        effectiveShortcutConfiguration:
            RemappingShortcutConfiguration
    ) throws {
        try GlobalShortcutConfigurationPolicy
            .validate(
                defaultShortcutConfiguration
            )

        for profile in profilesConfiguration.profiles {
            try rulesValidator
                .validate(
                    profile.rules
                )

            if let shortcutConfigurationOverride =
                profile.shortcutConfigurationOverride
            {
                try GlobalShortcutConfigurationPolicy
                    .validate(
                        shortcutConfigurationOverride
                    )
            }
        }

        try RemappingShortcutRuleConflictPolicy
            .validate(
                rules:
                    activeProfile.rules,
                shortcutConfiguration:
                    effectiveShortcutConfiguration
            )
    }
}
