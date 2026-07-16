//
//  UserDefaultsAppPreferencesStoreTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import Foundation
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class UserDefaultsAppPreferencesStoreTests:
    XCTestCase
{

    func testLoadReturnsDefaultPreferencesWhenNothingIsStored()
        throws
    {
        let suiteName =
            "UserDefaultsAppPreferencesStoreTests." +
            UUID().uuidString

        let userDefaults = try XCTUnwrap(
            UserDefaults(
                suiteName: suiteName
            )
        )

        defer {
            userDefaults.removePersistentDomain(
                forName: suiteName
            )
        }

        let defaultPreferences = AppPreferences(
            enableRemappingAtLaunch: false
        )

        let store =
            UserDefaultsAppPreferencesStore(
                userDefaults: userDefaults,
                defaultPreferences:
                    defaultPreferences
            )

        let loadedPreferences =
            try store.loadPreferences()

        XCTAssertEqual(
            loadedPreferences,
            defaultPreferences
        )
    }

    func testSavedPreferencesCanBeLoadedByAnotherStore()
        throws
    {
        let suiteName =
            "UserDefaultsAppPreferencesStoreTests." +
            UUID().uuidString

        let userDefaults = try XCTUnwrap(
            UserDefaults(
                suiteName: suiteName
            )
        )

        defer {
            userDefaults.removePersistentDomain(
                forName: suiteName
            )
        }

        let expectedPreferences = AppPreferences(
            enableRemappingAtLaunch: true
        )

        let savingStore =
            UserDefaultsAppPreferencesStore(
                userDefaults: userDefaults
            )

        try savingStore.savePreferences(
            expectedPreferences
        )

        let loadingStore =
            UserDefaultsAppPreferencesStore(
                userDefaults: userDefaults
            )

        let loadedPreferences =
            try loadingStore.loadPreferences()

        XCTAssertEqual(
            loadedPreferences,
            expectedPreferences
        )
    }
}
