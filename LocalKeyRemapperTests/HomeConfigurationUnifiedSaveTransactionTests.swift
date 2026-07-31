//
//  HomeConfigurationUnifiedSaveTransactionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import CoreGraphics
import Foundation
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class HomeConfigurationUnifiedSaveTransactionTests:
    XCTestCase
{
    func testCommitPersistsEveryHomeSettingAndAppliesSelectedActiveRules()
        throws
    {
        let context =
            makeContext()

        try context.shortcutController
            .start()

        let secondProfileID =
            context.secondProfile.id

        var renamedSecondProfile =
            context.secondProfile
        renamedSecondProfile.name =
            "  Gaming  "
        renamedSecondProfile.updatedAt =
            Date(
                timeIntervalSince1970:
                    50
            )

        let proposedShortcut =
            shortcut(
                keyCode:
                    KeyCode.j
            )

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            context.firstProfile,
                            renamedSecondProfile
                        ],
                        activeProfileID:
                            secondProfileID
                    ),
                launchBehavior:
                    .alwaysOn,
                shortcutConfiguration:
                    .toggle(
                        proposedShortcut
                    )
            )

        let result =
            try context.transaction
                .commit(
                    draft
                )

        XCTAssertEqual(
            context.profilesStore.configuration,
            result.committedSnapshot
                .profilesConfiguration
        )

        XCTAssertEqual(
            result.committedSnapshot
                .activeProfileID,
            secondProfileID
        )

        XCTAssertEqual(
            result.committedSnapshot
                .profile(
                    id:
                        secondProfileID
                )?
                .name,
            "Gaming"
        )

        XCTAssertEqual(
            context.preferencesController
                .preferences
                .launchBehavior,
            .alwaysOn
        )

        XCTAssertEqual(
            context.preferencesController
                .preferences
                .shortcutConfiguration,
            .toggle(
                proposedShortcut
            )
        )

        XCTAssertEqual(
            context.shortcutManager
                .registeredRegistrations,
            RemappingShortcutConfiguration
                .toggle(
                    proposedShortcut
                )
                .registrations
        )

        XCTAssertEqual(
            context.appliedRules,
            context.secondProfile.rules
        )

        XCTAssertTrue(
            result.profilesChanged
        )

        XCTAssertTrue(
            result.shortcutConfigurationChanged
        )
    }

    func testPreferenceFailureRollsBackProfilesAndShortcutRegistration()
        throws
    {
        let context =
            makeContext()

        try context.shortcutController
            .start()

        let previousConfiguration =
            context.profilesStore
                .configuration
        let previousShortcutConfiguration =
            context.preferencesController
                .preferences
                .shortcutConfiguration

        context.preferencesStore.saveError =
            UnifiedHomeTransactionTestError.expected

        var renamedProfile =
            context.firstProfile
        renamedProfile.name =
            "Renamed"

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            renamedProfile,
                            context.secondProfile
                        ],
                        activeProfileID:
                            context.secondProfile.id
                    ),
                launchBehavior:
                    .alwaysOn,
                shortcutConfiguration:
                    .toggle(
                        shortcut(
                            keyCode:
                                KeyCode.j
                        )
                    )
            )

        XCTAssertThrowsError(
            try context.transaction
                .commit(
                    draft
                )
        )

        XCTAssertEqual(
            context.profilesStore
                .configuration,
            previousConfiguration
        )

        XCTAssertEqual(
            context.preferencesController
                .preferences
                .shortcutConfiguration,
            previousShortcutConfiguration
        )

        XCTAssertEqual(
            context.shortcutManager
                .registeredRegistrations,
            previousShortcutConfiguration
                .registrations
        )

        XCTAssertNil(
            context.appliedRules
        )

        XCTAssertEqual(
            context.profilesStore
                .saveCallCount,
            2
        )
    }

    func testShortcutRegistrationFailureRollsBackProfilesBeforePreferencesWrite()
        throws
    {
        let context =
            makeContext()

        try context.shortcutController
            .start()

        let previousConfiguration =
            context.profilesStore
                .configuration

        context.shortcutManager.registerError =
            UnifiedHomeTransactionTestError.expected

        var renamedProfile =
            context.firstProfile
        renamedProfile.name =
            "Renamed"

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            renamedProfile,
                            context.secondProfile
                        ],
                        activeProfileID:
                            context.firstProfile.id
                    ),
                launchBehavior:
                    .alwaysOn,
                shortcutConfiguration:
                    .toggle(
                        shortcut(
                            keyCode:
                                KeyCode.j
                        )
                    )
            )

        XCTAssertThrowsError(
            try context.transaction
                .commit(
                    draft
                )
        )

        XCTAssertEqual(
            context.profilesStore
                .configuration,
            previousConfiguration
        )

        XCTAssertEqual(
            context.preferencesStore
                .saveCallCount,
            0
        )

        XCTAssertNil(
            context.appliedRules
        )
    }

    func testCommitPreservesRulesSavedAfterHomeDraftWasCreated()
        throws
    {
        let context =
            makeContext()

        let latestRules = [
            RemapRule(
                sourceKeyCode:
                    KeyCode.n,
                destinationKeyCode:
                    KeyCode.r
            )
        ]

        var persistedFirstProfile =
            context.firstProfile
        persistedFirstProfile.rules =
            latestRules
        persistedFirstProfile.updatedAt =
            Date(
                timeIntervalSince1970:
                    90
            )

        context.profilesStore.configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    persistedFirstProfile,
                    context.secondProfile
                ],
                activeProfileID:
                    context.firstProfile.id
            )

        var staleDraftProfile =
            context.firstProfile
        staleDraftProfile.name =
            "Renamed after Rules Save"
        staleDraftProfile.updatedAt =
            Date(
                timeIntervalSince1970:
                    80
            )

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            staleDraftProfile,
                            context.secondProfile
                        ],
                        activeProfileID:
                            context.firstProfile.id
                    ),
                launchBehavior:
                    context.preferencesController
                        .preferences
                        .launchBehavior,
                shortcutConfiguration:
                    context.preferencesController
                        .preferences
                        .shortcutConfiguration
            )

        let result =
            try context.transaction
                .commit(
                    draft
                )

        let committedFirstProfile =
            try XCTUnwrap(
                result.committedSnapshot
                    .profile(
                        id:
                            context.firstProfile.id
                    )
            )

        XCTAssertEqual(
            committedFirstProfile.name,
            "Renamed after Rules Save"
        )

        XCTAssertEqual(
            committedFirstProfile.rules,
            latestRules
        )

        XCTAssertEqual(
            committedFirstProfile.updatedAt,
            persistedFirstProfile.updatedAt
        )

        XCTAssertEqual(
            context.appliedRules,
            latestRules
        )
    }

    func testProfilePersistenceFailureDoesNotTouchPreferencesShortcutsOrRuntime()
        throws
    {
        let context =
            makeContext()

        try context.shortcutController
            .start()

        let previousShortcutConfiguration =
            context.preferencesController
                .preferences
                .shortcutConfiguration

        context.profilesStore.saveErrorsByCall[
            1
        ] =
            UnifiedHomeTransactionTestError.expected

        var renamedProfile =
            context.firstProfile
        renamedProfile.name =
            "Renamed"

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            renamedProfile,
                            context.secondProfile
                        ],
                        activeProfileID:
                            context.secondProfile.id
                    ),
                launchBehavior:
                    .alwaysOn,
                shortcutConfiguration:
                    .toggle(
                        shortcut(
                            keyCode:
                                KeyCode.j
                        )
                    )
            )

        XCTAssertThrowsError(
            try context.transaction
                .commit(
                    draft
                )
        )

        XCTAssertEqual(
            context.preferencesStore
                .saveCallCount,
            0
        )

        XCTAssertEqual(
            context.shortcutManager
                .registeredRegistrations,
            previousShortcutConfiguration
                .registrations
        )

        XCTAssertNil(
            context.appliedRules
        )
    }

    func testRollbackFailureReturnsDedicatedError() throws {
        let context =
            makeContext()

        try context.shortcutController
            .start()

        context.preferencesStore.saveError =
            UnifiedHomeTransactionTestError.expected
        context.profilesStore.saveErrorsByCall[
            2
        ] =
            UnifiedHomeTransactionTestError.expected

        var renamedProfile =
            context.firstProfile
        renamedProfile.name =
            "Renamed"

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            renamedProfile,
                            context.secondProfile
                        ],
                        activeProfileID:
                            context.firstProfile.id
                    ),
                launchBehavior:
                    .alwaysOn,
                shortcutConfiguration:
                    .toggle(
                        shortcut(
                            keyCode:
                                KeyCode.j
                        )
                    )
            )

        XCTAssertThrowsError(
            try context.transaction
                .commit(
                    draft
                )
        ) {
            error in

            XCTAssertEqual(
                error as? HomeConfigurationSaveTransactionError,
                .profileRollbackFailed
            )
        }

        XCTAssertNil(
            context.appliedRules
        )
    }

    func testInactiveProfileShortcutConflictDoesNotBlockHomeSave()
        throws
    {
        let context =
            makeContext()

        let reservedShortcut =
            shortcut(
                keyCode:
                    KeyCode.r
            )

        var inactiveProfile =
            context.secondProfile
        inactiveProfile.rules = [
            RemapRule(
                source:
                    reservedShortcut,
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.j
                    )
            )
        ]

        var persistedConfiguration =
            context.profilesStore
                .configuration

        guard
            let inactiveProfileIndex =
                persistedConfiguration
                    .profiles
                    .firstIndex(
                        where: {
                            $0.id
                                == inactiveProfile.id
                        }
                    )
        else {
            XCTFail(
                "The inactive profile was not present in the persisted configuration."
            )
            return
        }

        persistedConfiguration
            .profiles[
                inactiveProfileIndex
            ] =
                inactiveProfile

        context.profilesStore
            .configuration =
                persistedConfiguration

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            context.firstProfile,
                            inactiveProfile
                        ],
                        activeProfileID:
                            context.firstProfile.id
                    ),
                launchBehavior:
                    context.preferencesController
                        .preferences
                        .launchBehavior,
                shortcutConfiguration:
                    .toggle(
                        reservedShortcut
                    )
            )

        let result =
            try context.transaction
                .commit(
                    draft
                )

        XCTAssertEqual(
            result.committedSnapshot
                .activeProfileID,
            context.firstProfile.id
        )

        XCTAssertEqual(
            result.committedSnapshot
                .profile(
                    id:
                        inactiveProfile.id
                )?
                .rules,
            inactiveProfile.rules
        )

        XCTAssertEqual(
            context.appliedRules,
            context.firstProfile.rules
        )
    }

    func testProposedActiveProfileShortcutConflictBlocksHomeSave() {
        let context =
            makeContext()

        let reservedShortcut =
            shortcut(
                keyCode:
                    KeyCode.r
            )

        var proposedActiveProfile =
            context.secondProfile
        proposedActiveProfile.rules = [
            RemapRule(
                source:
                    reservedShortcut,
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.j
                    )
            )
        ]

        var persistedConfiguration =
            context.profilesStore
                .configuration

        guard
            let proposedActiveProfileIndex =
                persistedConfiguration
                    .profiles
                    .firstIndex(
                        where: {
                            $0.id
                                == proposedActiveProfile.id
                        }
                    )
        else {
            XCTFail(
                "The proposed active profile was not present in the persisted configuration."
            )
            return
        }

        persistedConfiguration
            .profiles[
                proposedActiveProfileIndex
            ] =
                proposedActiveProfile

        context.profilesStore
            .configuration =
                persistedConfiguration

        let previousConfiguration =
            context.profilesStore
                .configuration

        let draft =
            HomeConfigurationSnapshot(
                profilesConfiguration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            context.firstProfile,
                            proposedActiveProfile
                        ],
                        activeProfileID:
                            proposedActiveProfile.id
                    ),
                launchBehavior:
                    context.preferencesController
                        .preferences
                        .launchBehavior,
                shortcutConfiguration:
                    .toggle(
                        reservedShortcut
                    )
            )

        XCTAssertThrowsError(
            try context.transaction
                .commit(
                    draft
                )
        ) {
            error in

            XCTAssertNotNil(
                error as? RemappingShortcutRuleConflict
            )
        }

        XCTAssertEqual(
            context.profilesStore
                .configuration,
            previousConfiguration
        )

        XCTAssertNil(
            context.appliedRules
        )
    }

    private func makeContext()
        -> UnifiedHomeTransactionContext
    {
        let firstProfile =
            RemappingProfile(
                id:
                    UUID(),
                name:
                    "Profile 1",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            10
                    ),
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.v,
                        destinationKeyCode:
                            KeyCode.w
                    )
                ]
            )

        let secondProfile =
            RemappingProfile(
                id:
                    UUID(),
                name:
                    "Profile 2",
                createdAt:
                    Date(
                        timeIntervalSince1970:
                            20
                    ),
                rules: [
                    RemapRule(
                        sourceKeyCode:
                            KeyCode.b,
                        destinationKeyCode:
                            KeyCode.n
                    )
                ]
            )

        let profilesStore =
            UnifiedHomeProfilesStore(
                configuration:
                    RemappingProfilesConfiguration(
                        profiles: [
                            firstProfile,
                            secondProfile
                        ],
                        activeProfileID:
                            firstProfile.id
                    )
            )

        let initialShortcutConfiguration =
            RemappingShortcutConfiguration
                .toggle(
                    shortcut(
                        keyCode:
                            KeyCode.r
                    )
                )

        let initialPreferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    initialShortcutConfiguration
            )

        let preferencesStore =
            UnifiedHomePreferencesStore(
                preferences:
                    initialPreferences
            )

        let preferencesController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    initialPreferences
            )

        let shortcutManager =
            UnifiedHomeShortcutManager()

        let shortcutController =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                configuredRulesProvider: {
                    let configuration =
                        try profilesStore
                            .loadConfiguration()

                    guard
                        let activeProfile =
                            configuration.activeProfile
                    else {
                        throw RemappingProfilesConfigurationValidationError
                            .missingActiveProfile(
                                configuration.activeProfileID
                            )
                    }

                    return activeProfile.rules
                },
                actionHandler: {
                    _ in
                }
            )

        let context =
            UnifiedHomeTransactionContext(
                firstProfile:
                    firstProfile,
                secondProfile:
                    secondProfile,
                profilesStore:
                    profilesStore,
                preferencesStore:
                    preferencesStore,
                preferencesController:
                    preferencesController,
                shortcutManager:
                    shortcutManager,
                shortcutController:
                    shortcutController
            )

        context.transaction =
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
                    [weak context] rules in

                    context?.appliedRules =
                        rules
                }
            )

        return context
    }

    private func shortcut(
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

private nonisolated enum UnifiedHomeTransactionTestError:
    Error
{
    case expected
}

@MainActor
private final class UnifiedHomeTransactionContext {
    let firstProfile:
        RemappingProfile
    let secondProfile:
        RemappingProfile
    let profilesStore:
        UnifiedHomeProfilesStore
    let preferencesStore:
        UnifiedHomePreferencesStore
    let preferencesController:
        AppPreferencesController
    let shortcutManager:
        UnifiedHomeShortcutManager
    let shortcutController:
        GlobalShortcutController

    var transaction:
        HomeConfigurationSaveTransaction!

    var appliedRules:
        [RemapRule]?

    init(
        firstProfile:
            RemappingProfile,
        secondProfile:
            RemappingProfile,
        profilesStore:
            UnifiedHomeProfilesStore,
        preferencesStore:
            UnifiedHomePreferencesStore,
        preferencesController:
            AppPreferencesController,
        shortcutManager:
            UnifiedHomeShortcutManager,
        shortcutController:
            GlobalShortcutController
    ) {
        self.firstProfile =
            firstProfile
        self.secondProfile =
            secondProfile
        self.profilesStore =
            profilesStore
        self.preferencesStore =
            preferencesStore
        self.preferencesController =
            preferencesController
        self.shortcutManager =
            shortcutManager
        self.shortcutController =
            shortcutController
    }
}

@MainActor
private final class UnifiedHomeProfilesStore:
    RemappingProfilesStore
{
    var configuration:
        RemappingProfilesConfiguration

    var saveErrorsByCall:
        [Int: Error] = [:]

    private(set) var saveCallCount =
        0

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

        if let error =
            saveErrorsByCall[
                saveCallCount
            ]
        {
            throw error
        }

        self.configuration =
            configuration
    }
}

@MainActor
private final class UnifiedHomePreferencesStore:
    AppPreferencesStore
{
    private var preferences:
        AppPreferences

    private(set) var saveCallCount =
        0

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
    }
}

@MainActor
private final class UnifiedHomeShortcutManager:
    GlobalShortcutRegistering
{
    private(set) var registeredRegistrations:
        [GlobalShortcutRegistration] = []

    var registerError:
        Error?

    private var actionHandler:
        ((GlobalShortcutAction) -> Void)?

    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (GlobalShortcutAction) -> Void
    ) throws {
        if let registerError {
            throw registerError
        }

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
