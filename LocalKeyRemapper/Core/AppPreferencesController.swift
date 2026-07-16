//
//  AppPreferencesController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

/// Defines the application preference operations required by the UI
/// and the application coordinator.
@MainActor
protocol AppPreferencesControlling: AnyObject {

    /// Represents the preferences currently loaded in memory.
    var preferences: AppPreferences { get }

    /// Reloads preferences from local storage.
    func loadPreferences() throws

    /// Updates whether remapping should be enabled at launch.
    func setEnableRemappingAtLaunch(
        _ isEnabled: Bool
    ) throws
}

/// Coordinates in-memory application preferences and local storage.
///
/// The controller stores application behavior only and never receives
/// keyboard events or key-press history.
@MainActor
final class AppPreferencesController:
    AppPreferencesControlling
{

    private let store: AppPreferencesStore

    private(set) var preferences: AppPreferences

    init(
        store: AppPreferencesStore,
        initialPreferences: AppPreferences = .standard
    ) {
        self.store = store
        preferences = initialPreferences
    }

    func loadPreferences() throws {
        preferences = try store.loadPreferences()
    }

    func setEnableRemappingAtLaunch(
        _ isEnabled: Bool
    ) throws {
        guard
            preferences.enableRemappingAtLaunch
                != isEnabled
        else {
            return
        }

        var updatedPreferences = preferences
        updatedPreferences.enableRemappingAtLaunch =
            isEnabled

        try store.savePreferences(
            updatedPreferences
        )

        preferences = updatedPreferences
    }
}
