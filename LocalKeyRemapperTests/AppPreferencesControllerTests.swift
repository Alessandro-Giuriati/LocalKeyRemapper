//
//  AppPreferencesControllerTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/16/26.
//

import XCTest
@testable import LocalKeyRemapper

@MainActor
final class AppPreferencesControllerTests:
    XCTestCase
{

    func testLoadUpdatesCurrentPreferences()
        throws
    {
        let expectedPreferences = AppPreferences(
            enableRemappingAtLaunch: true
        )

        let store = PreferencesMockStore(
            preferences: expectedPreferences
        )

        let controller = AppPreferencesController(
            store: store
        )

        try controller.loadPreferences()

        XCTAssertEqual(
            controller.preferences,
            expectedPreferences
        )

        XCTAssertEqual(
            store.loadCallCount,
            1
        )
    }

    func testSettingLaunchPreferenceSavesAndUpdatesState()
        throws
    {
        let store = PreferencesMockStore(
            preferences: .standard
        )

        let controller = AppPreferencesController(
            store: store
        )

        try controller.loadPreferences()

        try controller
            .setEnableRemappingAtLaunch(true)

        XCTAssertTrue(
            controller.preferences
                .enableRemappingAtLaunch
        )

        XCTAssertEqual(
            store.savedPreferences,
            AppPreferences(
                enableRemappingAtLaunch: true
            )
        )

        XCTAssertEqual(
            store.saveCallCount,
            1
        )
    }

    func testSaveFailureDoesNotUpdateCurrentPreferences() {
        let store = PreferencesMockStore(
            preferences: .standard
        )

        store.saveError =
            PreferencesTestError.expected

        let controller = AppPreferencesController(
            store: store
        )

        do {
            try controller
                .setEnableRemappingAtLaunch(true)

            XCTFail(
                "Expected preference saving to fail."
            )
        } catch PreferencesTestError.expected {
            // Expected error.
        } catch {
            XCTFail(
                "Unexpected error: \(error)"
            )
        }

        XCTAssertFalse(
            controller.preferences
                .enableRemappingAtLaunch
        )

        XCTAssertNil(
            store.savedPreferences
        )
    }
}

nonisolated enum PreferencesTestError:
    Error
{
    case expected
}

@MainActor
final class PreferencesMockStore:
    AppPreferencesStore
{

    var storedPreferences: AppPreferences
    var loadError: Error?
    var saveError: Error?

    private(set) var loadCallCount = 0
    private(set) var saveCallCount = 0
    private(set) var savedPreferences:
        AppPreferences?

    init(
        preferences: AppPreferences
    ) {
        storedPreferences = preferences
    }

    func loadPreferences() throws
        -> AppPreferences
    {
        loadCallCount += 1

        if let loadError {
            throw loadError
        }

        return storedPreferences
    }

    func savePreferences(
        _ preferences: AppPreferences
    ) throws {
        saveCallCount += 1

        if let saveError {
            throw saveError
        }

        storedPreferences = preferences
        savedPreferences = preferences
    }
}
