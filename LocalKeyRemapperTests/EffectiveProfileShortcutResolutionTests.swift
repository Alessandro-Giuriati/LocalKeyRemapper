//
//  EffectiveProfileShortcutResolutionTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class EffectiveProfileShortcutResolutionTests:
    XCTestCase
{
    func testNilOverrideUsesDefaultConfiguration() {
        let defaultConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    nil
            )

        let resolvedConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        profile,
                    defaultConfiguration:
                        defaultConfiguration
                )

        XCTAssertEqual(
            resolvedConfiguration,
            defaultConfiguration
        )
    }

    func testExplicitDisabledOverrideReplacesEnabledDefault() {
        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .disabled
            )

        let resolvedConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        profile,
                    defaultConfiguration:
                        makeToggleConfiguration(
                            keyCode:
                                KeyCode.n
                        )
                )

        XCTAssertEqual(
            resolvedConfiguration,
            .disabled
        )
    }

    func testCustomOverrideReplacesDefaultConfiguration() {
        let defaultConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

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
                    customConfiguration
            )

        let resolvedConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        profile,
                    defaultConfiguration:
                        defaultConfiguration
                )

        XCTAssertEqual(
            resolvedConfiguration,
            customConfiguration
        )
    }

    func testMissingActiveProfileIsRejected() {
        let missingProfileID =
            fixedUUID(
                "3D697966-804F-458E-A7D0-A32DC7995875"
            )

        let existingProfile =
            RemappingProfile(
                id:
                    fixedUUID(
                        "40440C44-D2C8-4E5F-8BBF-53E70FDA7EF4"
                    ),
                name:
                    "Existing"
            )

        let configuration =
            RemappingProfilesConfiguration(
                profiles: [
                    existingProfile
                ],
                activeProfileID:
                    missingProfileID
            )

        XCTAssertThrowsError(
            try EffectiveRemappingShortcutConfigurationResolver
                .resolveActiveProfile(
                    in:
                        configuration,
                    defaultConfiguration:
                        .disabled
                )
        ) {
            error in

            XCTAssertEqual(
                error as?
                    RemappingProfilesConfigurationValidationError,
                .missingActiveProfile(
                    missingProfileID
                )
            )
        }
    }

    func testActiveRulesEditorUsesDraftDefaultWhenOverrideIsNil()
        throws
    {
        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    nil
            )

        let draftDefault =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let scopedController =
            makeScopedPreferencesController(
                profiles: [
                    profile
                ],
                activeProfileID:
                    profile.id,
                displayedProfileID:
                    profile.id,
                storedDefault:
                    .disabled,
                draftDefault:
                    draftDefault
            )

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            draftDefault
        )
    }

    func testActiveRulesEditorUsesProfileOverride()
        throws
    {
        let profileOverride =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    profileOverride
            )

        let scopedController =
            makeScopedPreferencesController(
                profiles: [
                    profile
                ],
                activeProfileID:
                    profile.id,
                displayedProfileID:
                    profile.id,
                storedDefault:
                    .disabled,
                draftDefault:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
            )

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            profileOverride
        )
    }

    func testInactiveRulesEditorAlwaysSeesDisabledConfiguration()
        throws
    {
        let activeProfile =
            RemappingProfile(
                name:
                    "Active"
            )

        let inactiveProfile =
            RemappingProfile(
                name:
                    "Inactive",
                shortcutConfigurationOverride:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.r
                    )
            )

        let scopedController =
            makeScopedPreferencesController(
                profiles: [
                    activeProfile,
                    inactiveProfile
                ],
                activeProfileID:
                    activeProfile.id,
                displayedProfileID:
                    inactiveProfile.id,
                storedDefault:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    ),
                draftDefault:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
            )

        XCTAssertEqual(
            scopedController
                .preferences
                .shortcutConfiguration,
            .disabled
        )
    }

    func testRemappingEnableUsesExplicitOffOverrideInsteadOfDefault()
    {
        let conflictingShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makeRule(
                        source:
                            conflictingShortcut
                    )
                ],
                shortcutConfigurationOverride:
                    .disabled
            )

        let context =
            makeRemappingControllerContext(
                profile:
                    profile,
                defaultConfiguration:
                    .toggle(
                        conflictingShortcut
                    )
            )

        context.controller.enable()

        XCTAssertEqual(
            context.controller.state,
            .enabled
        )

        XCTAssertEqual(
            context.eventTapManager
                .startCallCount,
            1
        )
    }

    func testRemappingEnableRejectsConflictWithCustomOverride()
    {
        let conflictingShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    makeRule(
                        source:
                            conflictingShortcut
                    )
                ],
                shortcutConfigurationOverride:
                    .toggle(
                        conflictingShortcut
                    )
            )

        let context =
            makeRemappingControllerContext(
                profile:
                    profile,
                defaultConfiguration:
                    .disabled
            )

        context.controller.enable()

        XCTAssertEqual(
            context.controller.state,
            .failed(
                .invalidRules
            )
        )

        XCTAssertEqual(
            context.eventTapManager
                .startCallCount,
            0
        )
    }

    private func makeScopedPreferencesController(
        profiles:
            [RemappingProfile],
        activeProfileID:
            UUID,
        displayedProfileID:
            UUID,
        storedDefault:
            RemappingShortcutConfiguration,
        draftDefault:
            RemappingShortcutConfiguration
    ) -> RulesWindowAppPreferencesController {
        let profilesConfiguration =
            RemappingProfilesConfiguration(
                profiles:
                    profiles,
                activeProfileID:
                    activeProfileID
            )

        let profilesStore =
            EffectiveShortcutProfilesStore(
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
            EffectiveShortcutPreferencesStore(
                preferences:
                    preferences
            )

        let baseController =
            AppPreferencesController(
                store:
                    preferencesStore,
                initialPreferences:
                    preferences
            )

        let scopedController =
            RulesWindowAppPreferencesController(
                baseController:
                    baseController,
                profilesStore:
                    profilesStore
            )

        scopedController.profileID =
            displayedProfileID

        scopedController
            .homeProfilesConfigurationProvider = {
                profilesConfiguration
            }

        scopedController
            .homeShortcutConfigurationProvider = {
                draftDefault
            }

        return scopedController
    }

    private func makeRemappingControllerContext(
        profile:
            RemappingProfile,
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) -> EffectiveShortcutRemappingContext {
        let profilesConfiguration =
            RemappingProfilesConfiguration(
                profiles: [
                    profile
                ],
                activeProfileID:
                    profile.id
            )

        let profilesStore =
            EffectiveShortcutProfilesStore(
                configuration:
                    profilesConfiguration
            )

        let eventTapManager =
            EffectiveShortcutEventTapManager()

        let controller =
            RemappingController(
                permissionService:
                    EffectiveShortcutPermissionService(),
                profilesStore:
                    profilesStore,
                rulesValidator:
                    RemappingRulesValidator(),
                remappingEngine:
                    RemappingEngine(),
                eventTapManager:
                    eventTapManager,
                shortcutConfigurationProvider: {
                    defaultConfiguration
                }
            )

        return EffectiveShortcutRemappingContext(
            controller:
                controller,
            eventTapManager:
                eventTapManager
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

    private func fixedUUID(
        _ value:
            String
    ) -> UUID {
        UUID(
            uuidString:
                value
        )!
    }
}

@MainActor
private struct EffectiveShortcutRemappingContext {
    let controller:
        RemappingController

    let eventTapManager:
        EffectiveShortcutEventTapManager
}

@MainActor
private final class EffectiveShortcutProfilesStore:
    RemappingProfilesStore
{
    private var configuration:
        RemappingProfilesConfiguration

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
        self.configuration =
            configuration
    }
}

@MainActor
private final class EffectiveShortcutPreferencesStore:
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

private nonisolated final class EffectiveShortcutPermissionService:
    AccessibilityPermissionChecking
{
    var isGranted:
        Bool
    {
        true
    }

    @discardableResult
    func requestAccess()
        -> Bool
    {
        true
    }
}

@MainActor
private final class EffectiveShortcutEventTapManager:
    EventTapManaging
{
    private(set) var isRunning = false
    private(set) var startCallCount = 0
    private(set) var stopCallCount = 0
    private(set) var pauseCallCount = 0
    private(set) var resumeCallCount = 0

    func start() throws {
        startCallCount +=
            1

        isRunning =
            true
    }

    func stop() {
        stopCallCount +=
            1

        isRunning =
            false
    }

    func pause() {
        pauseCallCount +=
            1
    }

    func resume() {
        resumeCallCount +=
            1
    }
}
