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
        _ isEnabled: Bool
    ) throws

    /// Updates or disables the global shortcut used to toggle remapping.
    ///
    /// Passing nil disables the configured shortcut.
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
        _ isEnabled: Bool
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

    func setToggleShortcut(
        _ shortcut:
            KeyCombination?
    ) throws {
        guard
            preferences.toggleShortcut
                != shortcut
        else {
            return
        }

        var updatedPreferences =
            preferences

        updatedPreferences.toggleShortcut =
            shortcut

        try saveAndApply(
            updatedPreferences
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
