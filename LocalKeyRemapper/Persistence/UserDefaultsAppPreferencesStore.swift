//
//  UserDefaultsAppPreferencesStore.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Foundation

/// Persists application preferences in the local UserDefaults domain.
///
/// This store never receives, records, or stores keyboard input.
@MainActor
final class UserDefaultsAppPreferencesStore:
    AppPreferencesStore
{

    private enum StorageKey {
        static let appPreferences =
            "appPreferences.v1"
    }

    private let userDefaults: UserDefaults
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let defaultPreferences: AppPreferences

    init(
        userDefaults: UserDefaults = .standard,
        defaultPreferences: AppPreferences = .standard
    ) {
        self.userDefaults = userDefaults
        self.defaultPreferences = defaultPreferences

        encoder = JSONEncoder()
        decoder = JSONDecoder()
    }

    func loadPreferences() throws -> AppPreferences {
        guard
            let data = userDefaults.data(
                forKey: StorageKey.appPreferences
            )
        else {
            return defaultPreferences
        }

        return try decoder.decode(
            AppPreferences.self,
            from: data
        )
    }

    func savePreferences(
        _ preferences: AppPreferences
    ) throws {
        let data = try encoder.encode(preferences)

        userDefaults.set(
            data,
            forKey: StorageKey.appPreferences
        )
    }
}
