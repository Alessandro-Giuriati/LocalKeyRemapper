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

    var profilesChanged:
        Bool
    {
        previousProfilesConfiguration
            != committedSnapshot
                .profilesConfiguration
    }

    var shortcutConfigurationChanged:
        Bool
    {
        previousShortcutConfiguration
            != committedSnapshot
                .shortcutConfiguration
    }
}

/// Commits every setting owned by the Home window as one coordinated operation.
///
/// The transaction deliberately persists profiles before applying shortcuts so
/// shortcut validation observes the proposed profile collection. If shortcut
/// registration or application-preference persistence then fails, the previous
/// profiles payload and shortcut registration are restored before the error is
/// returned.
///
/// Runtime rules are replaced only after every persistence step succeeds.
/// This guarantees that changing the active profile in the Home draft has no
/// effect on remapping until Save completes successfully.
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

        let previousShortcutConfiguration =
            appPreferencesController
                .preferences
                .shortcutConfiguration

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
                    .profile(
                        id:
                            normalizedProfilesConfiguration
                                .activeProfileID
                    )
        else {
            throw RemappingProfilesConfigurationValidationError
                .missingActiveProfile(
                    normalizedProfilesConfiguration
                        .activeProfileID
                )
        }

        try validateRulesAndShortcuts(
            profilesConfiguration:
                normalizedProfilesConfiguration,
            activeProfile:
                activeProfile,
            shortcutConfiguration:
                draft.shortcutConfiguration
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
                    draft.shortcutConfiguration,
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

        // This is intentionally the final state-changing operation. It cannot
        // make a partially persisted Home draft active.
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
                previousShortcutConfiguration
        )
    }

    /// Applies every blocking rule and shortcut policy before storage changes.
    ///
    /// Structural rule validation remains local to every profile. Shortcut
    /// conflicts are evaluated only for the profile proposed as active because
    /// inactive profiles cannot affect the current runtime.
    private func validateRulesAndShortcuts(
        profilesConfiguration:
            RemappingProfilesConfiguration,
        activeProfile:
            RemappingProfile,
        shortcutConfiguration:
            RemappingShortcutConfiguration
    ) throws {
        for profile in profilesConfiguration.profiles {
            try rulesValidator
                .validate(
                    profile.rules
                )
        }

        try RemappingShortcutRuleConflictPolicy
            .validate(
                rules:
                    activeProfile.rules,
                shortcutConfiguration:
                    shortcutConfiguration
            )
    }
}
