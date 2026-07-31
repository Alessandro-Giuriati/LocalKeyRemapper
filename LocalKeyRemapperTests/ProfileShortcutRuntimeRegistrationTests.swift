//
//  ProfileShortcutRuntimeRegistrationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileShortcutRuntimeRegistrationTests:
    XCTestCase
{
    func testStartRegistersEffectiveOverrideInsteadOfStoredDefault()
        throws
    {
        let defaultShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.n
            )

        let effectiveShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let engine =
            RemappingEngine(
                rules: [
                    makeRule(
                        source:
                            defaultShortcut
                    ),
                    makeRule(
                        source:
                            effectiveShortcut
                    )
                ]
            )

        let context =
            makeControllerContext(
                storedDefault:
                    .toggle(
                        defaultShortcut
                    ),
                effectiveConfiguration:
                    .toggle(
                        effectiveShortcut
                    ),
                engine:
                    engine
            )

        try context.controller.start()

        XCTAssertEqual(
            context.manager
                .registeredRegistrations,
            RemappingShortcutConfiguration
                .toggle(
                    effectiveShortcut
                )
                .registrations
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    effectiveShortcut
            ),
            .passThrough
        )

        XCTAssertNotEqual(
            engine.decision(
                for:
                    defaultShortcut
            ),
            .passThrough
        )
    }

    func testCaptureRestoresPreviouslyAppliedEffectiveConfiguration()
        throws
    {
        let effectiveConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    makeShortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        let context =
            makeControllerContext(
                storedDefault:
                    .disabled,
                effectiveConfiguration:
                    effectiveConfiguration
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
            effectiveConfiguration
                .registrations
        )
    }

    func testDefaultChangeWithUnchangedEffectiveOverrideDoesNotReregister()
        throws
    {
        let originalDefault =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let updatedDefault =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.e
            )

        let effectiveOverride =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.r
            )

        let context =
            makeControllerContext(
                storedDefault:
                    originalDefault,
                effectiveConfiguration:
                    effectiveOverride
            )

        try context.controller.start()

        XCTAssertEqual(
            context.manager
                .registerCallCount,
            1
        )

        try context.controller
            .applyConfiguration(
                defaultConfiguration:
                    updatedDefault,
                effectiveConfiguration:
                    effectiveOverride,
                persistingWith: {
                    try context
                        .preferencesController
                        .setShortcutConfiguration(
                            updatedDefault
                        )
                }
            )

        XCTAssertEqual(
            context.manager
                .registerCallCount,
            1
        )

        XCTAssertEqual(
            context.preferencesController
                .preferences
                .shortcutConfiguration,
            updatedDefault
        )

        XCTAssertEqual(
            context.manager
                .registeredRegistrations,
            effectiveOverride
                .registrations
        )
    }

    func testEffectiveChangeReregistersWhenDefaultIsUnchanged()
        throws
    {
        let defaultConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let previousEffectiveConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.r
            )

        let updatedEffectiveConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.e
            )

        let context =
            makeControllerContext(
                storedDefault:
                    defaultConfiguration,
                effectiveConfiguration:
                    previousEffectiveConfiguration
            )

        try context.controller.start()

        try context.controller
            .applyConfiguration(
                defaultConfiguration:
                    defaultConfiguration,
                effectiveConfiguration:
                    updatedEffectiveConfiguration,
                persistingWith: {}
            )

        XCTAssertEqual(
            context.manager
                .registerCallCount,
            2
        )

        XCTAssertEqual(
            context.manager
                .registeredRegistrations,
            updatedEffectiveConfiguration
                .registrations
        )
    }

    func testPersistenceFailureRestoresPreviousEffectiveConfiguration()
        throws
    {
        let previousShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let updatedShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let previousEffectiveConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    previousShortcut
                )

        let updatedEffectiveConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    updatedShortcut
                )

        let engine =
            RemappingEngine(
                rules: [
                    makeRule(
                        source:
                            previousShortcut
                    ),
                    makeRule(
                        source:
                            updatedShortcut
                    )
                ]
            )

        let context =
            makeControllerContext(
                storedDefault:
                    .disabled,
                effectiveConfiguration:
                    previousEffectiveConfiguration,
                engine:
                    engine
            )

        try context.controller.start()

        XCTAssertThrowsError(
            try context.controller
                .applyConfiguration(
                    defaultConfiguration:
                        .disabled,
                    effectiveConfiguration:
                        updatedEffectiveConfiguration,
                    persistingWith: {
                        throw RuntimeShortcutTestError
                            .expected
                    }
                )
        )

        XCTAssertEqual(
            context.manager
                .registeredRegistrations,
            previousEffectiveConfiguration
                .registrations
        )

        XCTAssertEqual(
            engine.decision(
                for:
                    previousShortcut
            ),
            .passThrough
        )

        XCTAssertNotEqual(
            engine.decision(
                for:
                    updatedShortcut
            ),
            .passThrough
        )
    }

    func testHomeSaveAllowsDefaultConflictWhenActiveOverrideIsOff()
        throws
    {
        let defaultShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.n
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makeRule(
                        source:
                            defaultShortcut
                    )
                ],
                shortcutConfigurationOverride:
                    nil
            )

        let context =
            makeTransactionContext(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    ),
                storedDefault:
                    .disabled
            )

        var draftProfile =
            profile

        draftProfile.shortcutConfigurationOverride =
            .disabled

        let result =
            try context.transaction.commit(
                HomeConfigurationSnapshot(
                    profilesConfiguration:
                        RemappingProfilesConfiguration(
                            profiles: [
                                draftProfile
                            ],
                            activeProfileID:
                                draftProfile.id
                        ),
                    launchBehavior:
                        .alwaysOff,
                    shortcutConfiguration:
                        .toggle(
                            defaultShortcut
                        )
                )
            )

        XCTAssertEqual(
            result.committedSnapshot
                .activeProfile?
                .shortcutConfigurationOverride,
            .disabled
        )

        XCTAssertEqual(
            context.preferencesController
                .preferences
                .shortcutConfiguration,
            .toggle(
                defaultShortcut
            )
        )

        XCTAssertTrue(
            context.manager
                .registeredRegistrations
                .isEmpty
        )
    }

    func testHomeSaveRegistersCustomActiveOverride()
        throws
    {
        let customConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    nil
            )

        let context =
            makeTransactionContext(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    ),
                storedDefault:
                    .disabled
            )

        var draftProfile =
            profile

        draftProfile.shortcutConfigurationOverride =
            customConfiguration

        let result =
            try context.transaction.commit(
                HomeConfigurationSnapshot(
                    profilesConfiguration:
                        RemappingProfilesConfiguration(
                            profiles: [
                                draftProfile
                            ],
                            activeProfileID:
                                draftProfile.id
                        ),
                    launchBehavior:
                        .alwaysOff,
                    shortcutConfiguration:
                        .disabled
                )
            )

        XCTAssertEqual(
            context.manager
                .registeredRegistrations,
            customConfiguration
                .registrations
        )

        XCTAssertTrue(
            result
                .effectiveShortcutConfigurationChanged
        )

        XCTAssertFalse(
            result
                .shortcutConfigurationChanged
        )
    }

    func testInvalidInactiveOverrideBlocksHomeSaveBeforePersistence()
        throws
    {
        let activeProfile =
            RemappingProfile(
                name:
                    "Active"
            )

        let invalidInactiveOverride =
            RemappingShortcutConfiguration
                .toggle(
                    KeyCombination(
                        keyCode:
                            KeyCode.r
                    )
                )

        let inactiveProfile =
            RemappingProfile(
                name:
                    "Inactive",
                shortcutConfigurationOverride:
                    invalidInactiveOverride
            )

        let originalConfiguration =
            RemappingProfilesConfiguration(
                profiles: [
                    activeProfile
                ],
                activeProfileID:
                    activeProfile.id
            )

        let context =
            makeTransactionContext(
                profilesConfiguration:
                    originalConfiguration,
                storedDefault:
                    .disabled
            )

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            activeProfile,
                            inactiveProfile
                        ],
                        activeProfileID:
                            activeProfile.id
                    ),
                launchBehavior:
                    .alwaysOff,
                shortcutConfiguration:
                    .disabled
            )

        XCTAssertThrowsError(
            try context.transaction
                .commit(
                    draft
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
            context.profilesStore
                .saveCallCount,
            0
        )

        XCTAssertEqual(
            context.preferencesStore
                .saveCallCount,
            0
        )

        XCTAssertEqual(
            try context.profilesStore
                .loadConfiguration(),
            originalConfiguration
        )
    }

    private func makeControllerContext(
        storedDefault:
            RemappingShortcutConfiguration,
        effectiveConfiguration:
            RemappingShortcutConfiguration,
        engine:
            RemappingEngine = RemappingEngine()
    ) -> RuntimeShortcutControllerContext {
        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    storedDefault
            )

        let preferencesStore =
            RuntimeShortcutPreferencesStore(
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

        let manager =
            RuntimeShortcutManager()

        let controller =
            GlobalShortcutController(
                shortcutManager:
                    manager,
                appPreferencesController:
                    preferencesController,
                remappingEngine:
                    engine,
                configuredRulesProvider: {
                    []
                },
                effectiveConfigurationProvider: {
                    effectiveConfiguration
                },
                actionHandler: {
                    _ in
                }
            )

        return RuntimeShortcutControllerContext(
            controller:
                controller,
            manager:
                manager,
            preferencesController:
                preferencesController
        )
    }

    private func makeTransactionContext(
        profilesConfiguration:
            RemappingProfilesConfiguration,
        storedDefault:
            RemappingShortcutConfiguration
    ) -> RuntimeShortcutTransactionContext {
        let profilesStore =
            RuntimeShortcutProfilesStore(
                configuration:
                    profilesConfiguration
            )

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    storedDefault
            )

        let preferencesStore =
            RuntimeShortcutPreferencesStore(
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

        let manager =
            RuntimeShortcutManager()

        let engine =
            RemappingEngine()

        let shortcutController =
            GlobalShortcutController(
                shortcutManager:
                    manager,
                appPreferencesController:
                    preferencesController,
                remappingEngine:
                    engine,
                configuredRulesProvider: {
                    let configuration =
                        try profilesStore
                            .loadConfiguration()

                    return configuration
                        .activeProfile?
                        .rules
                        ?? []
                },
                actionHandler: {
                    _ in
                }
            )

        let transaction =
            HomeConfigurationSaveTransaction(
                profilesStore:
                    profilesStore,
                profilesValidator:
                    RemappingProfilesConfigurationValidator(),
                rulesValidator:
                    RemappingRulesValidator(),
                appPreferencesController:
                    preferencesController,
                globalShortcutController:
                    shortcutController,
                activeRulesApplyHandler: {
                    engine.replaceRules(
                        $0
                    )
                }
            )

        return RuntimeShortcutTransactionContext(
            transaction:
                transaction,
            profilesStore:
                profilesStore,
            preferencesStore:
                preferencesStore,
            preferencesController:
                preferencesController,
            manager:
                manager
        )
    }

    private func makeToggleConfiguration(
        keyCode:
            CGKeyCode
    ) -> RemappingShortcutConfiguration {
        .toggle(
            makeShortcut(
                keyCode:
                    keyCode
            )
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

    private func makeRule(
        source:
            KeyCombination
    ) -> RemapRule {
        RemapRule(
            source:
                source,
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w,
                    modifiers:
                        source.modifiers
                )
        )
    }
}

@MainActor
private struct RuntimeShortcutControllerContext {
    let controller:
        GlobalShortcutController

    let manager:
        RuntimeShortcutManager

    let preferencesController:
        AppPreferencesController
}

@MainActor
private struct RuntimeShortcutTransactionContext {
    let transaction:
        HomeConfigurationSaveTransaction

    let profilesStore:
        RuntimeShortcutProfilesStore

    let preferencesStore:
        RuntimeShortcutPreferencesStore

    let preferencesController:
        AppPreferencesController

    let manager:
        RuntimeShortcutManager
}

private nonisolated enum RuntimeShortcutTestError:
    Error
{
    case expected
}

@MainActor
private final class RuntimeShortcutManager:
    GlobalShortcutRegistering
{
    private(set) var registeredRegistrations:
        [GlobalShortcutRegistration] = []

    private(set) var registerCallCount = 0

    private var actionHandler:
        ((GlobalShortcutAction) -> Void)?

    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (GlobalShortcutAction) -> Void
    ) throws {
        registerCallCount +=
            1

        registeredRegistrations =
            registrations

        self.actionHandler =
            actionHandler
    }

    func unregister() {
        registeredRegistrations
            .removeAll()

        actionHandler =
            nil
    }

    func stop() {
        unregister()
    }
}

@MainActor
private final class RuntimeShortcutProfilesStore:
    RemappingProfilesStore
{
    private var configuration:
        RemappingProfilesConfiguration

    private(set) var saveCallCount = 0

    init(
        configuration:
            RemappingProfilesConfiguration
    ) {
        self.configuration =
            configuration
    }

    func loadConfiguration()
        throws -> RemappingProfilesConfiguration
    {
        configuration
    }

    func saveConfiguration(
        _ configuration:
            RemappingProfilesConfiguration
    ) throws {
        saveCallCount +=
            1

        self.configuration =
            configuration
    }
}

@MainActor
private final class RuntimeShortcutPreferencesStore:
    AppPreferencesStore
{
    private var storedPreferences:
        AppPreferences

    private(set) var saveCallCount = 0

    init(
        preferences:
            AppPreferences
    ) {
        storedPreferences =
            preferences
    }

    func loadPreferences()
        throws -> AppPreferences
    {
        storedPreferences
    }

    func savePreferences(
        _ preferences:
            AppPreferences
    ) throws {
        saveCallCount +=
            1

        storedPreferences =
            preferences
    }
}
