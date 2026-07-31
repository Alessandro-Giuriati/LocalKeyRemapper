//
//  GlobalShortcutRulesEditorScopeTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import XCTest
@testable import LocalKeyRemapper

@MainActor
final class GlobalShortcutRulesEditorScopeTests:
    XCTestCase
{
    func testInactiveRulesEditorSeesDisabledConfigurationWithoutChangingRegistration()
        throws
    {
        let storedConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut()
                )

        let context =
            makeContext(
                storedConfiguration:
                    storedConfiguration,
                rulesEditorConfiguration:
                    .disabled
            )

        XCTAssertEqual(
            context.controller
                .configuredConfiguration,
            .disabled
        )

        try context.controller.start()

        XCTAssertEqual(
            context.manager
                .registeredRegistrations,
            storedConfiguration
                .registrations
        )
    }

    func testCaptureRestoresStoredConfigurationWhenInactiveRulesEditorSeesDisabled()
        throws
    {
        let storedConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut()
                )

        let context =
            makeContext(
                storedConfiguration:
                    storedConfiguration,
                rulesEditorConfiguration:
                    .disabled
            )

        try context.controller.start()

        context.controller
            .beginShortcutCapture()

        XCTAssertTrue(
            context.manager
                .registeredRegistrations
                .isEmpty
        )

        try context.controller
            .endShortcutCapture()

        XCTAssertEqual(
            context.manager
                .registeredRegistrations,
            storedConfiguration
                .registrations
        )
    }

    func testRulesEditorProviderCanExposeActiveProfileConfiguration()
    {
        let storedConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut()
                )

        let context =
            makeContext(
                storedConfiguration:
                    storedConfiguration,
                rulesEditorConfiguration:
                    storedConfiguration
            )

        XCTAssertEqual(
            context.controller
                .configuredConfiguration,
            storedConfiguration
        )
    }

    func testMissingRulesEditorProviderPreservesOriginalConfiguredConfigurationBehavior()
    {
        let storedConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut()
                )

        let preferences =
            makePreferences(
                shortcutConfiguration:
                    storedConfiguration
            )

        let store =
            RulesEditorScopePreferencesStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    store,
                initialPreferences:
                    preferences
            )

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    RulesEditorScopeShortcutManager(),
                appPreferencesController:
                    preferencesController,
                actionHandler: {
                    _ in
                }
            )

        XCTAssertEqual(
            controller.configuredConfiguration,
            storedConfiguration
        )
    }

    private func makeContext(
        storedConfiguration:
            RemappingShortcutConfiguration,
        rulesEditorConfiguration:
            RemappingShortcutConfiguration
    ) -> RulesEditorScopeContext {
        let preferences =
            makePreferences(
                shortcutConfiguration:
                    storedConfiguration
            )

        let store =
            RulesEditorScopePreferencesStore(
                preferences:
                    preferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    store,
                initialPreferences:
                    preferences
            )

        let manager =
            RulesEditorScopeShortcutManager()

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    manager,
                appPreferencesController:
                    preferencesController,
                rulesEditorShortcutConfigurationProvider: {
                    rulesEditorConfiguration
                },
                actionHandler: {
                    _ in
                }
            )

        return RulesEditorScopeContext(
            controller:
                controller,
            manager:
                manager
        )
    }

    private func makePreferences(
        shortcutConfiguration:
            RemappingShortcutConfiguration
    ) -> AppPreferences {
        AppPreferences(
            launchBehavior:
                .alwaysOff,
            lastRemappingEnabled:
                false,
            shortcutConfiguration:
                shortcutConfiguration
        )
    }

    private func makeShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.r,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
}

@MainActor
private struct RulesEditorScopeContext {
    let controller:
        GlobalShortcutController

    let manager:
        RulesEditorScopeShortcutManager
}

@MainActor
private final class RulesEditorScopeShortcutManager:
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
        actionHandler = nil
    }

    func stop() {
        unregister()
    }
}

@MainActor
private final class RulesEditorScopePreferencesStore:
    AppPreferencesStore
{
    private var preferences:
        AppPreferences

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
        self.preferences =
            preferences
    }
}
