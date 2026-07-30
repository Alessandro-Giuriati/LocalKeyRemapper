//
//  MainWindowShortcutValidationRefreshTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/30/26.
//

import AppKit
import XCTest
@testable import LocalKeyRemapper

@MainActor
final class MainWindowShortcutValidationRefreshTests:
    XCTestCase
{
    func testRulesSaveReenablesHomeSaveAfterShortcutConflictIsRemoved() {
        let shortcut =
            KeyCombination(
                keyCode:
                    KeyCode.r,
                modifiers: [
                    .control,
                    .option,
                    .command
                ]
            )

        let conflictingRule =
            RemapRule(
                source:
                    shortcut,
                destination:
                    KeyCombination(
                        keyCode:
                            KeyCode.w
                    )
            )

        let profileID =
            UUID()

        var profilesConfiguration =
            RemappingProfilesConfiguration(
                profiles: [
                    RemappingProfile(
                        id:
                            profileID,
                        name:
                            "Profile 1",
                        rules: [
                            conflictingRule
                        ]
                    )
                ],
                activeProfileID:
                    profileID
            )

        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    .disabled
            )

        let preferencesStore =
            MainWindowValidationPreferencesStore(
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

        let remappingController =
            MainWindowValidationRemappingController(
                rules: [
                    conflictingRule
                ]
            )

        let globalShortcutController =
            GlobalShortcutController(
                shortcutManager:
                    MainWindowValidationShortcutManager(),
                appPreferencesController:
                    preferencesController,
                actionHandler: {
                    _ in
                }
            )

        let homeSession =
            HomeConfigurationEditorSession(
                snapshot:
                    HomeConfigurationSnapshot(
                        profilesConfiguration:
                            profilesConfiguration,
                        launchBehavior:
                            preferences.launchBehavior,
                        shortcutConfiguration:
                            preferences.shortcutConfiguration
                    )
            )

        let controller =
            MainWindowController(
                remappingController:
                    remappingController,
                appPreferencesController:
                    preferencesController,
                globalShortcutController:
                    globalShortcutController,
                homeConfigurationEditorSession:
                    homeSession,
                saveHomeConfigurationHandler: {},
                profilesConfigurationProvider: {
                    profilesConfiguration
                },
                menuBarVisibilityChangeHandler: {
                    _ in
                },
                openRemappingRulesHandler: {},
                increaseTextSizeHandler: {},
                decreaseTextSizeHandler: {},
                resetTextSizeHandler: {},
                textScale:
                    1.0
            )

        controller.showWindow(
            nil
        )

        defer {
            controller.prepareForApplicationTermination()
            controller.window?.orderOut(
                nil
            )
        }

        homeSession.setShortcutConfiguration(
            .toggle(
                shortcut
            )
        )

        let saveButton =
            button(
                withIdentifier:
                    "home.save",
                in:
                    controller.window?.contentView
            )

        XCTAssertNotNil(
            saveButton
        )

        XCTAssertEqual(
            saveButton?.isEnabled,
            false
        )

        let disabledRule =
            RemapRule(
                source:
                    conflictingRule.source,
                destination:
                    conflictingRule.destination,
                matchingMode:
                    conflictingRule.matchingMode,
                overrides:
                    conflictingRule.overrides,
                isEnabled:
                    false,
                isBidirectional:
                    conflictingRule.isBidirectional
            )

        profilesConfiguration
            .profiles[0]
            .rules = [
                disabledRule
            ]

        NotificationCenter.default.post(
            name:
                AppConfigurationNotification
                    .remappingRulesDidChange,
            object:
                nil
        )

        XCTAssertEqual(
            saveButton?.isEnabled,
            true
        )
    }

    private func button(
        withIdentifier identifier:
            String,
        in view:
            NSView?
    ) -> NSButton? {
        guard let view else {
            return nil
        }

        if
            let button =
                view as?
                    NSButton,
            button.identifier?
                .rawValue
                == identifier
        {
            return button
        }

        for subview in
            view.subviews
        {
            if let matchingButton =
                button(
                    withIdentifier:
                        identifier,
                    in:
                        subview
                )
            {
                return matchingButton
            }
        }

        return nil
    }
}

@MainActor
private final class MainWindowValidationRemappingController:
    RemappingSettingsControlling
{
    private var rules:
        [RemapRule]

    init(
        rules:
            [RemapRule]
    ) {
        self.rules =
            rules
    }

    func loadConfiguredRules()
        throws -> [RemapRule]
    {
        rules
    }

    func loadConfiguredRules(
        for profileID:
            UUID
    ) throws -> [RemapRule] {
        rules
    }

    func replaceConfiguredRules(
        _ rules:
            [RemapRule]
    ) throws {
        self.rules =
            rules
    }

    func replaceConfiguredRules(
        _ rules:
            [RemapRule],
        for profileID:
            UUID
    ) throws {
        self.rules =
            rules
    }

    func beginKeyCapture() {}

    func endKeyCapture() {}
}

@MainActor
private final class MainWindowValidationPreferencesStore:
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

@MainActor
private final class MainWindowValidationShortcutManager:
    GlobalShortcutRegistering
{
    private(set) var registeredRegistrations:
        [GlobalShortcutRegistration] = []

    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void
    ) throws {
        registeredRegistrations =
            registrations
    }

    func unregister() {
        registeredRegistrations.removeAll()
    }

    func stop() {
        unregister()
    }
}
