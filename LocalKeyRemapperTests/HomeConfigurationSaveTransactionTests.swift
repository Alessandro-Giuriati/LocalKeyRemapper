//
//  HomeConfigurationSaveTransactionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import CoreGraphics
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class HomeConfigurationSaveTransactionTests:
    XCTestCase
{
    func testHomePreferencesArePersistedWithOneStoreWrite()
        throws
    {
        let store =
            HomeTransactionPreferencesStore(
                preferences:
                    .standard
            )

        let controller =
            AppPreferencesController(
                store:
                    store
            )

        let shortcutConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        try controller.setHomeConfiguration(
            launchBehavior:
                .alwaysOn,
            shortcutConfiguration:
                shortcutConfiguration
        )

        XCTAssertEqual(
            store.saveCallCount,
            1
        )

        XCTAssertEqual(
            controller
                .preferences
                .launchBehavior,
            .alwaysOn
        )

        XCTAssertEqual(
            controller
                .preferences
                .shortcutConfiguration,
            shortcutConfiguration
        )

        XCTAssertEqual(
            store
                .savedPreferences?
                .launchBehavior,
            .alwaysOn
        )

        XCTAssertEqual(
            store
                .savedPreferences?
                .shortcutConfiguration,
            shortcutConfiguration
        )
    }

    func testHomePreferenceSaveFailureKeepsPreviousInMemoryState() {
        let initialPreferences =
            AppPreferences.standard

        let store =
            HomeTransactionPreferencesStore(
                preferences:
                    initialPreferences
            )

        store.saveError =
            HomeTransactionTestError.expected

        let controller =
            AppPreferencesController(
                store:
                    store,
                initialPreferences:
                    initialPreferences
            )

        XCTAssertThrowsError(
            try controller.setHomeConfiguration(
                launchBehavior:
                    .alwaysOn,
                shortcutConfiguration:
                    .toggle(
                        makeShortcut(
                            keyCode:
                                KeyCode.r
                        )
                    )
            )
        )

        XCTAssertEqual(
            controller.preferences,
            initialPreferences
        )

        XCTAssertNil(
            store.savedPreferences
        )
    }

    func testShortcutApplicationUsesTheCallerHomePersistenceTransaction()
        throws
    {
        let previousShortcutConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.v
                    )
                )

        let initialPreferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    previousShortcutConfiguration
            )

        let store =
            HomeTransactionPreferencesStore(
                preferences:
                    initialPreferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    store,
                initialPreferences:
                    initialPreferences
            )

        let shortcutManager =
            HomeTransactionShortcutManager()

        let shortcutController =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                actionHandler: {
                    _ in
                }
            )

        try shortcutController.start()

        let newShortcutConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        try shortcutController.applyConfiguration(
            newShortcutConfiguration,
            persistingWith: {
                try preferencesController
                    .setHomeConfiguration(
                        launchBehavior:
                            .alwaysOn,
                        shortcutConfiguration:
                            newShortcutConfiguration
                    )
            }
        )

        XCTAssertEqual(
            shortcutManager
                .registeredRegistrations,
            newShortcutConfiguration
                .registrations
        )

        XCTAssertEqual(
            preferencesController
                .preferences
                .launchBehavior,
            .alwaysOn
        )

        XCTAssertEqual(
            preferencesController
                .preferences
                .shortcutConfiguration,
            newShortcutConfiguration
        )

        XCTAssertEqual(
            store.saveCallCount,
            1
        )
    }

    func testHomePersistenceFailureRestoresPreviousShortcutRegistration()
        throws
    {
        let previousConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.v
                    )
                )

        let initialPreferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    previousConfiguration
            )

        let store =
            HomeTransactionPreferencesStore(
                preferences:
                    initialPreferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    store,
                initialPreferences:
                    initialPreferences
            )

        let shortcutManager =
            HomeTransactionShortcutManager()

        let shortcutController =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                actionHandler: {
                    _ in
                }
            )

        try shortcutController.start()

        let proposedConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        XCTAssertThrowsError(
            try shortcutController.applyConfiguration(
                proposedConfiguration,
                persistingWith: {
                    throw HomeTransactionTestError.expected
                }
            )
        )

        XCTAssertEqual(
            shortcutManager
                .registeredRegistrations,
            previousConfiguration
                .registrations
        )

        XCTAssertEqual(
            preferencesController.preferences,
            initialPreferences
        )
    }

    private func makeShortcut(
        keyCode:
            CGKeyCode
    ) -> KeyCombination {
        KeyCombination(
            keyCode:
                keyCode,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
}

private nonisolated enum HomeTransactionTestError:
    Error
{
    case expected
}

@MainActor
private final class HomeTransactionPreferencesStore:
    AppPreferencesStore
{
    private var preferences:
        AppPreferences

    private(set) var saveCallCount =
        0

    private(set) var savedPreferences:
        AppPreferences?

    var saveError:
        Error?

    init(
        preferences:
            AppPreferences
    ) {
        self.preferences =
            preferences
    }

    func loadPreferences()
        throws -> AppPreferences
    {
        preferences
    }

    func savePreferences(
        _ preferences:
            AppPreferences
    ) throws {
        saveCallCount +=
            1

        if let saveError {
            throw saveError
        }

        self.preferences =
            preferences

        savedPreferences =
            preferences
    }
}

@MainActor
private final class HomeTransactionShortcutManager:
    GlobalShortcutRegistering
{
    private(set) var registeredRegistrations:
        [GlobalShortcutRegistration] = []

    private var actionHandler:
        ((GlobalShortcutAction) -> Void)?

    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (GlobalShortcutAction) -> Void
    ) throws {
        registeredRegistrations =
            registrations

        self.actionHandler =
            actionHandler
    }

    func unregister() {
        registeredRegistrations.removeAll()
        actionHandler =
            nil
    }

    func stop() {
        unregister()
    }
}
