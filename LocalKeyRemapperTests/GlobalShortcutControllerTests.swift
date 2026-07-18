//
//  GlobalShortcutControllerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/17/26.
//

import XCTest
@testable import LocalKeyRemapper

@MainActor
final class GlobalShortcutConfigurationControllerTests:
    XCTestCase
{
    func testStartRegistersStoredToggleConfiguration()
        throws
    {
        let shortcut =
            makeToggleShortcut()

        let context =
            makeContext(
                configuration:
                    .toggle(
                        shortcut
                    )
            )

        try context.controller.start()

        XCTAssertEqual(
            context
                .shortcutManager
                .registeredRegistrations,
            [
                GlobalShortcutRegistration(
                    action:
                        .toggle,
                    shortcut:
                        shortcut
                )
            ]
        )
    }

    func testStartRegistersSeparateConfiguration()
        throws
    {
        let enableShortcut =
            makeEnableShortcut()

        let disableShortcut =
            makeDisableShortcut()

        let configuration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        enableShortcut,
                    disable:
                        disableShortcut
                )

        let context =
            makeContext(
                configuration:
                    configuration
            )

        try context.controller.start()

        XCTAssertEqual(
            context
                .shortcutManager
                .registeredRegistrations,
            configuration.registrations
        )
    }

    func testDisabledConfigurationRemovesRegistrations()
        throws
    {
        let context =
            makeContext(
                configuration:
                    .disabled
            )

        try context
            .shortcutManager
            .register(
                [
                    GlobalShortcutRegistration(
                        action:
                            .toggle,
                        shortcut:
                            makeToggleShortcut()
                    )
                ],
                actionHandler: {
                    _ in
                }
            )

        try context.controller.start()

        XCTAssertTrue(
            context
                .shortcutManager
                .registeredRegistrations
                .isEmpty
        )
    }

    func testRegisteredActionsAreForwarded()
        throws
    {
        var receivedActions:
            [GlobalShortcutAction] = []

        let context =
            makeContext(
                configuration:
                    .separate(
                        enable:
                            makeEnableShortcut(),
                        disable:
                            makeDisableShortcut()
                    ),
                actionHandler: {
                    action in

                    receivedActions.append(
                        action
                    )
                }
            )

        try context.controller.start()

        context
            .shortcutManager
            .perform(
                .enable
            )

        context
            .shortcutManager
            .perform(
                .disable
            )

        XCTAssertEqual(
            receivedActions,
            [
                .enable,
                .disable
            ]
        )
    }

    func testSetConfigurationRegistersAndPersistsIt()
        throws
    {
        let newConfiguration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        makeEnableShortcut(),
                    disable:
                        makeDisableShortcut()
                )

        let context =
            makeContext(
                configuration:
                    .toggle(
                        makeToggleShortcut()
                    )
            )

        try context.controller.setConfiguration(
            newConfiguration
        )

        XCTAssertEqual(
            context
                .shortcutManager
                .registeredRegistrations,
            newConfiguration.registrations
        )

        XCTAssertEqual(
            context
                .preferencesController
                .preferences
                .shortcutConfiguration,
            newConfiguration
        )

        XCTAssertEqual(
            context
                .preferencesStore
                .saveCallCount,
            1
        )
    }

    func testIdenticalEnableAndDisableShortcutsAreRejected()
        throws
    {
        let sharedShortcut =
            makeEnableShortcut()

        let context =
            makeContext(
                configuration:
                    .toggle(
                        makeToggleShortcut()
                    )
            )

        XCTAssertThrowsError(
            try context.controller
                .setConfiguration(
                    .separate(
                        enable:
                            sharedShortcut,
                        disable:
                            sharedShortcut
                    )
                )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    GlobalShortcutConfigurationError,
                .duplicateShortcut
            )
        }

        XCTAssertEqual(
            context
                .shortcutManager
                .registerCallCount,
            0
        )

        XCTAssertEqual(
            context
                .preferencesStore
                .saveCallCount,
            0
        )
    }

    func testShortcutWithOneModifierIsAccepted()
        throws
    {
        let context =
            makeContext(
                configuration:
                    .toggle(
                        makeToggleShortcut()
                    )
            )

        let shortcut =
            KeyCombination(
                keyCode:
                    KeyCode.r,
                modifiers:
                    [
                        .command
                    ]
            )

        try context.controller
            .setConfiguration(
                .toggle(
                    shortcut
                )
            )

        XCTAssertEqual(
            context
                .shortcutManager
                .registeredRegistrations,
            [
                GlobalShortcutRegistration(
                    action:
                        .toggle,
                    shortcut:
                        shortcut
                )
            ]
        )

        XCTAssertEqual(
            context
                .preferencesStore
                .saveCallCount,
            1
        )
    }

    func testShortcutWithoutModifiersIsRejected()
        throws
    {
        let context =
            makeContext(
                configuration:
                    .toggle(
                        makeToggleShortcut()
                    )
            )

        let unsafeShortcut =
            KeyCombination(
                keyCode:
                    KeyCode.r
            )

        XCTAssertThrowsError(
            try context.controller
                .setConfiguration(
                    .toggle(
                        unsafeShortcut
                    )
                )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    GlobalShortcutConfigurationError,
                .insufficientModifiers(
                    .toggle
                )
            )
        }

        XCTAssertEqual(
            context
                .shortcutManager
                .registerCallCount,
            0
        )

        XCTAssertEqual(
            context
                .preferencesStore
                .saveCallCount,
            0
        )
    }

    func testRegistrationFailureRestoresPreviousConfiguration()
        throws
    {
        let previousConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeToggleShortcut()
                )

        let newConfiguration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        makeEnableShortcut(),
                    disable:
                        makeDisableShortcut()
                )

        let context =
            makeContext(
                configuration:
                    previousConfiguration
            )

        try context.controller.start()

        context
            .shortcutManager
            .registrationErrors =
                [
                    GlobalShortcutTestError
                        .expected
                ]

        XCTAssertThrowsError(
            try context.controller
                .setConfiguration(
                    newConfiguration
                )
        )

        XCTAssertEqual(
            context
                .shortcutManager
                .registeredRegistrations,
            previousConfiguration
                .registrations
        )

        XCTAssertEqual(
            context
                .preferencesController
                .preferences
                .shortcutConfiguration,
            previousConfiguration
        )

        XCTAssertEqual(
            context
                .preferencesStore
                .saveCallCount,
            0
        )
    }

    func testPersistenceFailureRestoresPreviousConfiguration()
        throws
    {
        let previousConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeToggleShortcut()
                )

        let newConfiguration =
            RemappingShortcutConfiguration
                .separate(
                    enable:
                        makeEnableShortcut(),
                    disable:
                        makeDisableShortcut()
                )

        let context =
            makeContext(
                configuration:
                    previousConfiguration
            )

        try context.controller.start()

        context
            .preferencesStore
            .saveError =
                GlobalShortcutTestError
                    .expected

        XCTAssertThrowsError(
            try context.controller
                .setConfiguration(
                    newConfiguration
                )
        )

        XCTAssertEqual(
            context
                .shortcutManager
                .registeredRegistrations,
            previousConfiguration
                .registrations
        )

        XCTAssertEqual(
            context
                .preferencesController
                .preferences
                .shortcutConfiguration,
            previousConfiguration
        )
    }

    func testSeparateConfigurationProtectsBothShortcutSources()
        throws
    {
        let enableShortcut =
            makeEnableShortcut()

        let disableShortcut =
            makeDisableShortcut()

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            enableShortcut,
                        destination:
                            makeDestinationShortcut()
                    ),
                    RemapRule(
                        source:
                            disableShortcut,
                        destination:
                            makeDestinationShortcut()
                    )
                ]
            )

        let context =
            makeContext(
                configuration:
                    .separate(
                        enable:
                            enableShortcut,
                        disable:
                            disableShortcut
                    ),
                remappingEngine:
                    engine
            )

        try context.controller.start()

        XCTAssertEqual(
            engine.decision(
                for:
                    enableShortcut
            ),
            .passThrough
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    disableShortcut
            ),
            .passThrough
        )
    }

    func testDisablingShortcutsRemovesRemappingProtection()
        throws
    {
        let shortcut =
            makeToggleShortcut()

        let destination =
            makeDestinationShortcut()

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            shortcut,
                        destination:
                            destination
                    )
                ]
            )

        let context =
            makeContext(
                configuration:
                    .toggle(
                        shortcut
                    ),
                remappingEngine:
                    engine
            )

        try context.controller.start()

        XCTAssertEqual(
            engine.decision(
                for:
                    shortcut
            ),
            .passThrough
        )

        try context.controller.setConfiguration(
            .disabled
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    shortcut
            ),
            .replaceWith(
                destination
            )
        )
    }

    func testShortcutCaptureTemporarilyRemovesAndRestoresRegistrations()
        throws
    {
        let configuration =
            RemappingShortcutConfiguration
                .toggle(
                    makeToggleShortcut()
                )

        let context =
            makeContext(
                configuration:
                    configuration
            )

        try context.controller.start()

        context.controller.beginShortcutCapture()

        XCTAssertTrue(
            context
                .shortcutManager
                .registeredRegistrations
                .isEmpty
        )

        try context.controller.endShortcutCapture()

        XCTAssertEqual(
            context
                .shortcutManager
                .registeredRegistrations,
            configuration.registrations
        )
    }

    func testRepeatedShortcutCaptureSuspensionIsIdempotent()
        throws
    {
        let context =
            makeContext(
                configuration:
                    .toggle(
                        makeToggleShortcut()
                    )
            )

        try context.controller.start()

        context.controller.beginShortcutCapture()
        context.controller.beginShortcutCapture()

        XCTAssertEqual(
            context
                .shortcutManager
                .unregisterCallCount,
            1
        )

        try context.controller.endShortcutCapture()
        try context.controller.endShortcutCapture()

        XCTAssertEqual(
            context
                .shortcutManager
                .registerCallCount,
            2
        )
    }

    func testStopRemovesRegistrationsAndReservations()
        throws
    {
        let shortcut =
            makeToggleShortcut()

        let destination =
            makeDestinationShortcut()

        let engine =
            RemappingEngine(
                rules: [
                    RemapRule(
                        source:
                            shortcut,
                        destination:
                            destination
                    )
                ]
            )

        let context =
            makeContext(
                configuration:
                    .toggle(
                        shortcut
                    ),
                remappingEngine:
                    engine
            )

        try context.controller.start()
        context.controller.stop()

        XCTAssertTrue(
            context
                .shortcutManager
                .registeredRegistrations
                .isEmpty
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    shortcut
            ),
            .replaceWith(
                destination
            )
        )
    }

    private func makeContext(
        configuration:
            RemappingShortcutConfiguration,
        remappingEngine:
            RemappingEngine = RemappingEngine(),
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void = {
                _ in
            }
    ) -> GlobalShortcutTestContext {
        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    configuration
            )

        let preferencesStore =
            GlobalShortcutPreferencesMockStore(
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
                    remappingEngine,
                actionHandler:
                    actionHandler
            )

        return GlobalShortcutTestContext(
            controller:
                controller,
            shortcutManager:
                shortcutManager,
            preferencesController:
                preferencesController,
            preferencesStore:
                preferencesStore
        )
    }

    private func makeToggleShortcut()
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

    private func makeEnableShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.e,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }

    private func makeDisableShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.d,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }

    private func makeDestinationShortcut()
        -> KeyCombination
    {
        KeyCombination(
            keyCode:
                KeyCode.w,
            modifiers: [
                .control,
                .option,
                .command
            ]
        )
    }
}

@MainActor
private struct GlobalShortcutTestContext {
    let controller:
        GlobalShortcutController

    let shortcutManager:
        GlobalShortcutMockManager

    let preferencesController:
        AppPreferencesController

    let preferencesStore:
        GlobalShortcutPreferencesMockStore
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
    private(set) var registeredRegistrations:
        [GlobalShortcutRegistration] = []

    private(set) var registerCallCount = 0
    private(set) var unregisterCallCount = 0
    private(set) var stopCallCount = 0

    var registrationErrors:
        [Error] = []

    private var registeredActionHandler:
        ((
            GlobalShortcutAction
        ) -> Void)?

    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void
    ) throws {
        registerCallCount += 1

        registeredRegistrations.removeAll()
        registeredActionHandler = nil

        if !registrationErrors.isEmpty {
            throw registrationErrors
                .removeFirst()
        }

        registeredRegistrations =
            registrations

        registeredActionHandler =
            actionHandler
    }

    func unregister() {
        unregisterCallCount += 1

        registeredRegistrations.removeAll()
        registeredActionHandler = nil
    }

    func stop() {
        stopCallCount += 1
        unregister()
    }

    func perform(
        _ action:
            GlobalShortcutAction
    ) {
        guard
            registeredRegistrations
                .contains(
                    where: {
                        $0.action == action
                    }
                )
        else {
            return
        }

        registeredActionHandler?(
            action
        )
    }
}

@MainActor
private final class GlobalShortcutPreferencesMockStore:
    AppPreferencesStore
{
    private var preferences:
        AppPreferences

    private(set) var saveCallCount = 0

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
        saveCallCount += 1

        if let saveError {
            throw saveError
        }

        self.preferences =
            preferences
    }
}
