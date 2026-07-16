//
//  AppPreferencesControllerTests.swift
//  LocalKeyRemapperTests
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
            launchBehavior: .restoreLastState,
            lastRemappingEnabled: true
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

    func testSettingLaunchBehaviorSavesAndUpdatesState()
        throws
    {
        let store = PreferencesMockStore(
            preferences: .standard
        )

        let controller = AppPreferencesController(
            store: store
        )

        try controller.setLaunchBehavior(
            .alwaysOn
        )

        XCTAssertEqual(
            controller.preferences.launchBehavior,
            .alwaysOn
        )

        XCTAssertEqual(
            store.savedPreferences,
            AppPreferences(
                launchBehavior: .alwaysOn,
                lastRemappingEnabled: false
            )
        )

        XCTAssertEqual(
            store.saveCallCount,
            1
        )
    }

    func testSettingLastRemappingStateSavesAndUpdatesState()
        throws
    {
        let store = PreferencesMockStore(
            preferences: .standard
        )

        let controller = AppPreferencesController(
            store: store
        )

        try controller.setLastRemappingEnabled(
            true
        )

        XCTAssertTrue(
            controller.preferences
                .lastRemappingEnabled
        )

        XCTAssertEqual(
            store.savedPreferences,
            AppPreferences(
                launchBehavior: .alwaysOff,
                lastRemappingEnabled: true
            )
        )
    }

    func testUnchangedLaunchBehaviorDoesNotSave()
        throws
    {
        let store = PreferencesMockStore(
            preferences: .standard
        )

        let controller = AppPreferencesController(
            store: store
        )

        try controller.setLaunchBehavior(
            .alwaysOff
        )

        XCTAssertEqual(
            store.saveCallCount,
            0
        )
    }

    func testLaunchBehaviorSaveFailureDoesNotUpdateCurrentPreferences() {
        let store = PreferencesMockStore(
            preferences: .standard
        )

        store.saveError =
            PreferencesTestError.expected

        let controller = AppPreferencesController(
            store: store
        )

        do {
            try controller.setLaunchBehavior(
                .alwaysOn
            )

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

        XCTAssertEqual(
            controller.preferences,
            .standard
        )

        XCTAssertNil(
            store.savedPreferences
        )
    }

    func testLastStateSaveFailureDoesNotUpdateCurrentPreferences() {
        let store = PreferencesMockStore(
            preferences: .standard
        )

        store.saveError =
            PreferencesTestError.expected

        let controller = AppPreferencesController(
            store: store
        )

        do {
            try controller.setLastRemappingEnabled(
                true
            )

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
                .lastRemappingEnabled
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
