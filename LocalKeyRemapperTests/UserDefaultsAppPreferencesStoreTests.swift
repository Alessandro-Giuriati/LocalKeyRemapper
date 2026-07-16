//
//  UserDefaultsAppPreferencesStoreTests.swift
//  LocalKeyRemapperTests
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
        let context = try makeTestContext()
        defer { context.cleanUp() }

        let defaultPreferences = AppPreferences(
            launchBehavior: .alwaysOff,
            lastRemappingEnabled: false
        )

        let store = UserDefaultsAppPreferencesStore(
            userDefaults: context.userDefaults,
            defaultPreferences: defaultPreferences
        )

        XCTAssertEqual(
            try store.loadPreferences(),
            defaultPreferences
        )
    }

    func testSavedPreferencesCanBeLoadedByAnotherStore()
        throws
    {
        let context = try makeTestContext()
        defer { context.cleanUp() }

        let expectedPreferences = AppPreferences(
            launchBehavior: .restoreLastState,
            lastRemappingEnabled: true
        )

        let savingStore = UserDefaultsAppPreferencesStore(
            userDefaults: context.userDefaults
        )

        try savingStore.savePreferences(
            expectedPreferences
        )

        let loadingStore = UserDefaultsAppPreferencesStore(
            userDefaults: context.userDefaults
        )

        XCTAssertEqual(
            try loadingStore.loadPreferences(),
            expectedPreferences
        )
    }

    func testLegacyEnabledPreferenceMigratesToAlwaysOn()
        throws
    {
        let context = try makeTestContext()
        defer { context.cleanUp() }

        try storeLegacyPreference(
            true,
            in: context.userDefaults
        )

        let store = UserDefaultsAppPreferencesStore(
            userDefaults: context.userDefaults
        )

        XCTAssertEqual(
            try store.loadPreferences(),
            AppPreferences(
                launchBehavior: .alwaysOn,
                lastRemappingEnabled: false
            )
        )
    }

    func testLegacyDisabledPreferenceMigratesToAlwaysOff()
        throws
    {
        let context = try makeTestContext()
        defer { context.cleanUp() }

        try storeLegacyPreference(
            false,
            in: context.userDefaults
        )

        let store = UserDefaultsAppPreferencesStore(
            userDefaults: context.userDefaults
        )

        XCTAssertEqual(
            try store.loadPreferences(),
            AppPreferences(
                launchBehavior: .alwaysOff,
                lastRemappingEnabled: false
            )
        )
    }

    private func makeTestContext() throws
        -> PreferencesStoreTestContext
    {
        let suiteName =
            "UserDefaultsAppPreferencesStoreTests." +
            UUID().uuidString

        let userDefaults = try XCTUnwrap(
            UserDefaults(
                suiteName: suiteName
            )
        )

        return PreferencesStoreTestContext(
            suiteName: suiteName,
            userDefaults: userDefaults
        )
    }

    private func storeLegacyPreference(
        _ enableRemappingAtLaunch: Bool,
        in userDefaults: UserDefaults
    ) throws {
        let legacyPreferences =
            LegacyAppPreferences(
                enableRemappingAtLaunch:
                    enableRemappingAtLaunch
            )

        let data = try JSONEncoder().encode(
            legacyPreferences
        )

        userDefaults.set(
            data,
            forKey: "appPreferences.v1"
        )
    }
}

private nonisolated struct LegacyAppPreferences:
    Codable
{
    let enableRemappingAtLaunch: Bool
}

private struct PreferencesStoreTestContext {
    let suiteName: String
    let userDefaults: UserDefaults

    func cleanUp() {
        userDefaults.removePersistentDomain(
            forName: suiteName
        )
    }
}
