//
//  AppPreferencesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

/// Defines local loading and saving operations for application
/// preferences that do not contain keyboard input.
@MainActor
protocol AppPreferencesStore: AnyObject {

    /// Loads the currently stored application preferences.
    func loadPreferences() throws -> AppPreferences

    /// Replaces the currently stored application preferences.
    func savePreferences(
        _ preferences: AppPreferences
    ) throws
}
