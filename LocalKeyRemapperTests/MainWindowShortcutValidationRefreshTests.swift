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
    func testRulesSaveReenablesHomeSaveAfterActiveProfileShortcutConflictIsRemoved() {
        let shortcut =
            makeShortcut()

        let conflictingRule =
            makeConflictingRule(
                shortcut:
                    shortcut
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

        let context =
            makeContext(
                profilesConfiguration:
                    profilesConfiguration,
                profilesConfigurationProvider: {
                    profilesConfiguration
                }
            )

        defer {
            close(
                context.controller
            )
        }

        context.homeSession
            .setShortcutConfiguration(
                .toggle(
                    shortcut
                )
            )

        XCTAssertFalse(
            context.saveButton.isEnabled
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

        XCTAssertTrue(
            context.saveButton.isEnabled
        )
    }

    func testInactiveProfileShortcutConflictDoesNotDisableHomeSave() {
        let shortcut =
            makeShortcut()

        let activeProfileID =
            UUID()

        let inactiveProfileID =
            UUID()

        let profilesConfiguration =
            RemappingProfilesConfiguration(
                profiles: [
                    RemappingProfile(
                        id:
                            activeProfileID,
                        name:
                            "Active",
                        rules: []
                    ),
                    RemappingProfile(
                        id:
                            inactiveProfileID,
                        name:
                            "Inactive Conflict",
                        rules: [
                            makeConflictingRule(
                                shortcut:
                                    shortcut
                            )
                        ]
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let context =
            makeContext(
                profilesConfiguration:
                    profilesConfiguration
            )

        defer {
            close(
                context.controller
            )
        }

        context.homeSession
            .setShortcutConfiguration(
                .toggle(
                    shortcut
                )
            )

        XCTAssertTrue(
            context.saveButton.isEnabled
        )

        XCTAssertFalse(
            visibleText(
                in:
                    context.controller
                        .window?
                        .contentView
            )
            .contains(
                "Inactive Conflict"
            )
        )
    }

    func testProposingConflictingProfileAsActiveDisablesHomeSaveAndIdentifiesProfile()
        throws
    {
        let shortcut =
            makeShortcut()

        let activeProfileID =
            UUID()

        let conflictingProfileID =
            UUID()

        let profilesConfiguration =
            RemappingProfilesConfiguration(
                profiles: [
                    RemappingProfile(
                        id:
                            activeProfileID,
                        name:
                            "Current",
                        rules: []
                    ),
                    RemappingProfile(
                        id:
                            conflictingProfileID,
                        name:
                            "Gaming",
                        rules: [
                            makeConflictingRule(
                                shortcut:
                                    shortcut
                            )
                        ]
                    )
                ],
                activeProfileID:
                    activeProfileID
            )

        let context =
            makeContext(
                profilesConfiguration:
                    profilesConfiguration
            )

        defer {
            close(
                context.controller
            )
        }

        context.homeSession
            .setShortcutConfiguration(
                .toggle(
                    shortcut
                )
            )

        XCTAssertTrue(
            context.saveButton.isEnabled
        )

        try context.homeSession
            .setActiveProfile(
                conflictingProfileID
            )

        XCTAssertFalse(
            context.saveButton.isEnabled
        )

        let text =
            visibleText(
                in:
                    context.controller
                        .window?
                        .contentView
            )

        XCTAssertTrue(
            text.contains(
                "The proposed shortcut conflicts with an exact mapping in “Gaming”."
            )
        )
    }

    private struct Context {
        let controller:
            MainWindowController

        let homeSession:
            HomeConfigurationEditorSession

        let saveButton:
            NSButton
    }

    private func makeContext(
        profilesConfiguration:
            RemappingProfilesConfiguration,
        profilesConfigurationProvider:
            (() throws -> RemappingProfilesConfiguration)? = nil
    ) -> Context {
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
                rules:
                    profilesConfiguration
                        .activeProfile?
                        .rules
                        ?? []
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

        let provider =
            profilesConfigurationProvider
                ?? {
                    profilesConfiguration
                }

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
                profilesConfigurationProvider:
                    provider,
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

        guard
            let saveButton =
                button(
                    withIdentifier:
                        "home.save",
                    in:
                        controller.window?
                            .contentView
                )
        else {
            XCTFail(
                "The Home Save button was not created."
            )

            return Context(
                controller:
                    controller,
                homeSession:
                    homeSession,
                saveButton:
                    NSButton()
            )
        }

        return Context(
            controller:
                controller,
            homeSession:
                homeSession,
            saveButton:
                saveButton
        )
    }

    private func close(
        _ controller:
            MainWindowController
    ) {
        controller.prepareForApplicationTermination()
        controller.window?.orderOut(
            nil
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

    private func makeConflictingRule(
        shortcut:
            KeyCombination
    ) -> RemapRule {
        RemapRule(
            source:
                shortcut,
            destination:
                KeyCombination(
                    keyCode:
                        KeyCode.w
                )
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

    private func visibleText(
        in view:
            NSView?
    ) -> String {
        guard let view else {
            return ""
        }

        var values:
            [String] = []

        if
            let textField =
                view as?
                    NSTextField,
            !textField.isHidden,
            !textField.stringValue.isEmpty
        {
            values.append(
                textField.stringValue
            )
        }

        for subview in
            view.subviews
        {
            let childText =
                visibleText(
                    in:
                        subview
                )

            if !childText.isEmpty {
                values.append(
                    childText
                )
            }
        }

        return values.joined(
            separator:
                "\n"
        )
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
