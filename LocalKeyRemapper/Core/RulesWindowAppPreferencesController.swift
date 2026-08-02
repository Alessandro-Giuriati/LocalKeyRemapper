//
//  RulesWindowAppPreferencesController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import Foundation

/// Presents application preferences to the reusable Rules window while
/// restricting shortcut validation to the profile that is active in the
/// current Home draft.
///
/// The Home draft is authoritative for editor-time validation because it may
/// contain a proposed active profile, proposed default shortcut configuration,
/// or proposed profile-specific override that has not been committed yet.
///
/// Profiles that are inactive in the Home draft still expose every normal
/// application preference, but their shortcut configuration is presented as
/// disabled. This prevents inactive profiles from showing shortcut-conflict
/// errors or Preserve Modifiers bypass warnings that cannot affect the proposed
/// runtime configuration.
///
/// All writes are delegated to the original application-preferences
/// controller. This adapter stores no keyboard input and performs no polling.
@MainActor
final class RulesWindowAppPreferencesController:
    AppPreferencesControlling
{
    private let baseController:
        AppPreferencesControlling

    private let profilesStore:
        RemappingProfilesStore

    /// Supplies the latest Home-draft profiles configuration when Home exists.
    ///
    /// Returning nil falls back to the persisted profiles configuration. The
    /// closure is installed by AppCoordinator after the shared Home session is
    /// created, avoiding a retain cycle and keeping this adapter testable.
    var homeProfilesConfigurationProvider:
        (() -> RemappingProfilesConfiguration?)?

    /// Supplies the latest Home-draft default shortcut configuration when Home
    /// exists.
    ///
    /// Returning nil falls back to the locally stored application preference.
    var homeShortcutConfigurationProvider:
        (() -> RemappingShortcutConfiguration?)?

    /// Stable identity currently displayed by the reusable Rules window.
    ///
    /// Nil means that no profile is currently bound to the window.
    var profileID:
        UUID?

    init(
        baseController:
            AppPreferencesControlling,
        profilesStore:
            RemappingProfilesStore
    ) {
        self.baseController =
            baseController

        self.profilesStore =
            profilesStore
    }

    var preferences:
        AppPreferences
    {
        var scopedPreferences =
            baseController.preferences

        let profilesConfiguration =
            homeProfilesConfigurationProvider?()
            ?? (try? profilesStore
                .loadConfiguration())

        guard
            let profileID,
            let profilesConfiguration,
            let displayedProfile =
                profilesConfiguration.profile(
                    id:
                        profileID
                ),
            profilesConfiguration.activeProfileID
                == profileID
        else {
            scopedPreferences.shortcutConfiguration =
                .disabled

            return scopedPreferences
        }

        let defaultConfiguration =
            homeShortcutConfigurationProvider?()
            ?? baseController
                .preferences
                .shortcutConfiguration

        scopedPreferences.shortcutConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        displayedProfile,
                    defaultConfiguration:
                        defaultConfiguration
                )

        return scopedPreferences
    }

    func loadPreferences() throws {
        try baseController
            .loadPreferences()
    }

    func setLaunchBehavior(
        _ launchBehavior:
            RemappingLaunchBehavior
    ) throws {
        try baseController
            .setLaunchBehavior(
                launchBehavior
            )
    }

    func setHomeConfiguration(
        launchBehavior:
            RemappingLaunchBehavior,
        shortcutConfiguration:
            RemappingShortcutConfiguration
    ) throws {
        try baseController
            .setHomeConfiguration(
                launchBehavior:
                    launchBehavior,
                shortcutConfiguration:
                    shortcutConfiguration
            )
    }

    func setLastRemappingEnabled(
        _ isEnabled:
            Bool
    ) throws {
        try baseController
            .setLastRemappingEnabled(
                isEnabled
            )
    }

    func setShowsMenuBarIcon(
        _ showsMenuBarIcon:
            Bool
    ) throws {
        try baseController
            .setShowsMenuBarIcon(
                showsMenuBarIcon
            )
    }

    func setConfirmsRuleRemoval(
        _ confirmsRuleRemoval:
            Bool
    ) throws {
        try baseController
            .setConfirmsRuleRemoval(
                confirmsRuleRemoval
            )
    }

    func setShortcutConfiguration(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        try baseController
            .setShortcutConfiguration(
                configuration
            )
    }

    func setToggleShortcut(
        _ shortcut:
            KeyCombination?
    ) throws {
        try baseController
            .setToggleShortcut(
                shortcut
            )
    }
}
