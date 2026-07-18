//
//  GlobalShortcutControllerTests.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import XCTest
@testable import LocalKeyRemapper

@MainActor
final class GlobalShortcutControllerTests:
    XCTestCase
{
    func testStartRegistersStoredShortcut()
        throws
    {
        let shortcut =
            makeShortcut()

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    shortcut
            )

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                action: {}
            )

        try controller.start()

        XCTAssertEqual(
            shortcutManager
                .registeredShortcut,
            shortcut
        )

        XCTAssertEqual(
            shortcutManager
                .registerCallCount,
            1
        )
    }

    func testStartWithoutShortcutRemovesRegistration()
        throws
    {
        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    nil
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                action: {}
            )

        try controller.start()

        XCTAssertNil(
            shortcutManager
                .registeredShortcut
        )

        XCTAssertEqual(
            shortcutManager
                .unregisterCallCount,
            1
        )
    }
    
    func testRegisteredShortcutPerformsAction()
        throws
    {
        var actionCallCount = 0

        let shortcut =
            makeShortcut()

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    shortcut
            )

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                action: {
                    actionCallCount += 1
                }
            )

        try controller.start()

        shortcutManager
            .performRegisteredAction()

        XCTAssertEqual(
            actionCallCount,
            1
        )
    }

    func testSettingShortcutRegistersAndPersistsIt()
        throws
    {
        let shortcut =
            makeShortcut()

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    .standard
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                action: {}
            )

        try controller.setShortcut(
            shortcut
        )

        XCTAssertEqual(
            shortcutManager
                .registeredShortcut,
            shortcut
        )

        XCTAssertEqual(
            preferencesController
                .preferences
                .toggleShortcut,
            shortcut
        )

        XCTAssertEqual(
            preferencesStore
                .saveCallCount,
            1
        )
    }

    func testClearingShortcutUnregistersAndPersistsNil()
        throws
    {
        let shortcut =
            makeShortcut()

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    shortcut
            )

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        try shortcutManager.register(
            shortcut,
            action: {}
        )

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                action: {}
            )

        try controller.setShortcut(
            nil
        )

        XCTAssertNil(
            shortcutManager
                .registeredShortcut
        )

        XCTAssertNil(
            preferencesController
                .preferences
                .toggleShortcut
        )
    }

    func testRegistrationFailureKeepsPreviousPreference()
        throws
    {
        let previousShortcut =
            makeShortcut()

        let newShortcut =
            KeyCombination(
                keyCode:
                    KeyCode.w,
                modifiers: [
                    .control,
                    .command
                ]
            )

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    previousShortcut
            )

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        try shortcutManager.register(
            previousShortcut,
            action: {}
        )

        shortcutManager
            .nextRegistrationError =
                GlobalShortcutTestError
                    .expected

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                action: {}
            )

        XCTAssertThrowsError(
            try controller.setShortcut(
                newShortcut
            )
        )

        XCTAssertEqual(
            preferencesController
                .preferences
                .toggleShortcut,
            previousShortcut
        )

        XCTAssertEqual(
            shortcutManager
                .registeredShortcut,
            previousShortcut
        )

        XCTAssertEqual(
            preferencesStore
                .saveCallCount,
            0
        )
    }

    func testPersistenceFailureRestoresPreviousRegistration()
        throws
    {
        let previousShortcut =
            makeShortcut()

        let newShortcut =
            KeyCombination(
                keyCode:
                    KeyCode.w,
                modifiers: [
                    .option,
                    .command
                ]
            )

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    previousShortcut
            )

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        preferencesStore.saveError =
            GlobalShortcutTestError
                .expected

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        try shortcutManager.register(
            previousShortcut,
            action: {}
        )

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                action: {}
            )

        XCTAssertThrowsError(
            try controller.setShortcut(
                newShortcut
            )
        )

        XCTAssertEqual(
            shortcutManager
                .registeredShortcut,
            previousShortcut
        )

        XCTAssertEqual(
            preferencesController
                .preferences
                .toggleShortcut,
            previousShortcut
        )
    }

    private func makeShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.v,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
    
    func testStartProtectsStoredShortcutFromRemapping()
        throws
    {
        let source =
            makeShortcut()

        let destination =
            KeyCombination(
                keyCode:
                    KeyCode.w,
                modifiers: [
                    .control,
                    .option,
                    .command
                ]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            source,
                        destination:
                            destination
                    )
                ]
            )

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    source
            )

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                remappingEngine:
                    engine,
                action: {}
            )

        try controller.start()

        XCTAssertEqual(
            engine.decision(
                for: source
            ),
            .passThrough
        )
    }

    func testClearingShortcutRemovesRemappingProtection()
        throws
    {
        let source =
            makeShortcut()

        let destination =
            KeyCombination(
                keyCode:
                    KeyCode.w,
                modifiers: [
                    .control,
                    .option,
                    .command
                ]
            )

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            source,
                        destination:
                            destination
                    )
                ]
            )

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                toggleShortcut:
                    source
            )

        let preferencesStore =
            PreferencesMockStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let shortcutManager =
            GlobalShortcutMockManager()

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                remappingEngine:
                    engine,
                action: {}
            )

        try controller.start()
        try controller.setShortcut(nil)

        XCTAssertEqual(
            engine.decision(
                for: source
            ),
            .replaceWith(
                destination
            )
        )
    }
}

private nonisolated enum GlobalShortcutTestError:
    Error
{
    case expected
}

@MainActor
private final class GlobalShortcutMockManager:
    GlobalShortcutRegistering
{
    private(set) var registeredShortcut:
        KeyCombination?

    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var stopCallCount = 0

    var nextRegistrationError:
        Error?

    private var registeredAction:
        (() -> Void)?

    func register(
        _ shortcut:
            KeyCombination,
        action:
            @escaping () -> Void
    ) throws {
        registerCallCount += 1

        if let nextRegistrationError {
            self.nextRegistrationError =
                nil

            throw nextRegistrationError
        }

        registeredShortcut =
            shortcut

        registeredAction =
            action
    }

    func unregister() {
        unregisterCallCount += 1

        registeredShortcut =
            nil

        registeredAction =
            nil
    }

    func stop() {
        stopCallCount += 1
        unregister()
    }

    func performRegisteredAction() {
        registeredAction?()
    }
}
