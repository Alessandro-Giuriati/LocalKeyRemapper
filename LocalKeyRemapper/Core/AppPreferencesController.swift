//
//  AppPreferencesController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

/// Defines the application preference operations required by the UI
/// and the application coordinator.
@MainActor
protocol AppPreferencesControlling:
    AnyObject
{
    /// Represents the preferences currently loaded in memory.
    var preferences:
        AppPreferences
    {
        get
    }

    /// Reloads preferences from local storage.
    func loadPreferences() throws

    /// Updates how remapping should behave at application launch.
    func setLaunchBehavior(
        _ launchBehavior:
            RemappingLaunchBehavior
    ) throws

    /// Updates the most recently observed enabled or disabled state.
    func setLastRemappingEnabled(
        _ isEnabled:
            Bool
    ) throws

    /// Updates whether the optional menu bar icon should be visible.
    func setShowsMenuBarIcon(
        _ showsMenuBarIcon:
            Bool
    ) throws

    /// Updates whether removing a rule requires confirmation.
    func setConfirmsRuleRemoval(
        _ confirmsRuleRemoval:
            Bool
    ) throws

    /// Updates the complete global shortcut configuration.
    func setShortcutConfiguration(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws

    /// Compatibility operation for the existing single-shortcut
    /// controller.
    ///
    /// Passing nil disables global keyboard control.
    func setToggleShortcut(
        _ shortcut:
            KeyCombination?
    ) throws
}

/// Coordinates in-memory application preferences and local storage.
///
/// The controller stores application behavior and configured shortcuts
/// only. It never receives or records keyboard input.
@MainActor
final class AppPreferencesController:
    AppPreferencesControlling
{
    private let store:
        AppPreferencesStore

    private(set) var preferences:
        AppPreferences

    init(
        store:
            AppPreferencesStore,
        initialPreferences:
            AppPreferences = .standard
    ) {
        self.store =
            store

        preferences =
            initialPreferences
    }

    func loadPreferences() throws {
        preferences =
            try store.loadPreferences()
    }

    func setLaunchBehavior(
        _ launchBehavior:
            RemappingLaunchBehavior
    ) throws {
        guard
            preferences.launchBehavior
                != launchBehavior
        else {
            return
        }

        var updatedPreferences =
            preferences

        updatedPreferences.launchBehavior =
            launchBehavior

        try saveAndApply(
            updatedPreferences
        )
    }

    func setLastRemappingEnabled(
        _ isEnabled:
            Bool
    ) throws {
        guard
            preferences.lastRemappingEnabled
                != isEnabled
        else {
            return
        }

        var updatedPreferences =
            preferences

        updatedPreferences.lastRemappingEnabled =
            isEnabled

        try saveAndApply(
            updatedPreferences
        )
    }

    func setShowsMenuBarIcon(
        _ showsMenuBarIcon:
            Bool
    ) throws {
        guard
            preferences.showsMenuBarIcon
                != showsMenuBarIcon
        else {
            return
        }

        var updatedPreferences =
            preferences

        updatedPreferences.showsMenuBarIcon =
            showsMenuBarIcon

        try saveAndApply(
            updatedPreferences
        )
    }

    func setConfirmsRuleRemoval(
        _ confirmsRuleRemoval:
            Bool
    ) throws {
        guard
            preferences.confirmsRuleRemoval
                != confirmsRuleRemoval
        else {
            return
        }

        var updatedPreferences =
            preferences

        updatedPreferences.confirmsRuleRemoval =
            confirmsRuleRemoval

        try saveAndApply(
            updatedPreferences
        )
    }

    func setShortcutConfiguration(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        guard
            preferences.shortcutConfiguration
                != configuration
        else {
            return
        }

        var updatedPreferences =
            preferences

        updatedPreferences.shortcutConfiguration =
            configuration

        try saveAndApply(
            updatedPreferences
        )
    }

    func setToggleShortcut(
        _ shortcut:
            KeyCombination?
    ) throws {
        let configuration:
            RemappingShortcutConfiguration

        if let shortcut {
            configuration =
                .toggle(
                    shortcut
                )
        } else {
            configuration =
                .disabled
        }

        try setShortcutConfiguration(
            configuration
        )
    }

    private func saveAndApply(
        _ updatedPreferences:
            AppPreferences
    ) throws {
        try store.savePreferences(
            updatedPreferences
        )

        preferences =
            updatedPreferences
    }
}
