//
//  HomeProfileShortcutSheetCoordinatorTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import AppKit
import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class HomeProfileShortcutSheetCoordinatorTests:
    XCTestCase
{
    func testProfilesEditCallbackPresentsRequestedProfileSheet()
        throws
    {
        let profile =
            RemappingProfile(
                name:
                    "Gaming"
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        context.profilesSectionView
            .editShortcutForVisibleProfileForTesting(
                at:
                    0
            )

        XCTAssertEqual(
            context.coordinator
                .presentedProfileID,
            profile.id
        )

        XCTAssertNotNil(
            context.coordinator
                .presentedSheetControllerForTesting
        )
    }

    func testCoordinatorRenamesDefaultShortcutSection()
        throws
    {
        let profile =
            RemappingProfile(
                name:
                    "Gaming"
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        let contentView =
            try XCTUnwrap(
                context.controller
                    .window?
                    .contentView
            )

        let shortcutSettingsView:
            GlobalShortcutSettingsView =
                try XCTUnwrap(
                    descendant(
                        of:
                            GlobalShortcutSettingsView.self,
                        in:
                            contentView
                    )
                )

        XCTAssertEqual(
            shortcutSettingsView
                .defaultSectionTitleForTesting,
            "Default Global Shortcuts"
        )

        XCTAssertTrue(
            shortcutSettingsView
                .defaultSectionDescriptionForTesting?
                .contains(
                    "Use Default"
                )
                == true
        )
    }

    func testCoordinatorPassesRememberedToggleToProfileSheet()
        throws
    {
        let rememberedToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                shortcutConfigurationOverride:
                    .disabled,
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        toggleShortcut:
                            rememberedToggle
                    )
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        context.coordinator
            .presentProfileShortcutEditorForTesting(
                for:
                    profile.id
            )

        let sheet =
            try XCTUnwrap(
                context.coordinator
                    .presentedSheetControllerForTesting
            )

        sheet.setModeForTesting(
            .toggle
        )

        XCTAssertEqual(
            sheet.proposalForTesting,
            .complete(
                .toggle(
                    rememberedToggle
                )
            )
        )

        XCTAssertTrue(
            sheet.canApplyForTesting
        )
    }

    func testApplyingSheetOverrideCreatesOneHomeUndoAction()
        throws
    {
        let profile =
            RemappingProfile(
                name:
                    "Gaming"
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        context.coordinator
            .presentProfileShortcutEditorForTesting(
                for:
                    profile.id
            )

        let sheet =
            try XCTUnwrap(
                context.coordinator
                    .presentedSheetControllerForTesting
            )

        sheet.setModeForTesting(
            .off
        )

        XCTAssertTrue(
            sheet.canApplyForTesting
        )

        sheet.applyForTesting()

        XCTAssertEqual(
            context.homeSession
                .draft
                .profile(
                    id:
                        profile.id
                )?
                .shortcutConfigurationOverride,
            .disabled
        )

        XCTAssertEqual(
            context.homeSession
                .historyEntryCount,
            1
        )

        XCTAssertTrue(
            context.homeSession
                .hasUnsavedChanges
        )

        XCTAssertNil(
            context.coordinator
                .presentedSheetControllerForTesting
        )
    }

    func testDefaultConflictIsIgnoredWhenActiveProfileUsesExplicitOff()
        throws
    {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    exactRule(
                        source:
                            shortcut
                    )
                ],
                shortcutConfigurationOverride:
                    .disabled
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        context.homeSession
            .setShortcutConfiguration(
                .toggle(
                    shortcut
                )
            )

        XCTAssertTrue(
            context.saveButton
                .isEnabled
        )
    }

    func testDefaultConflictBlocksWhenActiveProfileUsesDefault()
        throws
    {
        let shortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    exactRule(
                        source:
                            shortcut
                    )
                ],
                shortcutConfigurationOverride:
                    nil
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        context.homeSession
            .setShortcutConfiguration(
                .toggle(
                    shortcut
                )
            )

        XCTAssertFalse(
            context.saveButton
                .isEnabled
        )
    }

    func testInactiveProfileSheetAllowsShortcutMatchingInactiveRules()
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
                rules: [
                    exactRule(
                        source:
                            AppPreferences
                                .defaultToggleShortcut
                    )
                ]
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            activeProfile,
                            inactiveProfile
                        ],
                        activeProfileID:
                            activeProfile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        context.coordinator
            .presentProfileShortcutEditorForTesting(
                for:
                    inactiveProfile.id
            )

        let sheet =
            try XCTUnwrap(
                context.coordinator
                    .presentedSheetControllerForTesting
            )

        sheet.setModeForTesting(
            .toggle
        )

        XCTAssertNil(
            sheet.validationMessageForTesting
        )

        XCTAssertTrue(
            sheet.canApplyForTesting
        )

        sheet.applyForTesting()

        XCTAssertEqual(
            context.homeSession
                .draft
                .profile(
                    id:
                        inactiveProfile.id
                )?
                .shortcutConfigurationOverride,
            .toggle(
                AppPreferences
                    .defaultToggleShortcut
            )
        )
    }

    func testRulesSaveRefreshesOpenProfileSheetValidation()
        throws
    {
        let conflictingShortcut =
            AppPreferences
                .defaultToggleShortcut

        let profile =
            RemappingProfile(
                name:
                    "Gaming",
                rules: [
                    exactRule(
                        source:
                            conflictingShortcut
                    )
                ]
            )

        let context =
            try makeContext(
                profilesConfiguration:
                    configuration(
                        profiles: [
                            profile
                        ],
                        activeProfileID:
                            profile.id
                    )
            )

        defer {
            close(
                context
            )
        }

        context.coordinator
            .presentProfileShortcutEditorForTesting(
                for:
                    profile.id
            )

        let sheet =
            try XCTUnwrap(
                context.coordinator
                    .presentedSheetControllerForTesting
            )

        sheet.setModeForTesting(
            .toggle
        )

        XCTAssertNotNil(
            sheet.validationMessageForTesting
        )

        XCTAssertFalse(
            sheet.canApplyForTesting
        )

        var updatedProfile =
            profile

        updatedProfile.rules =
            []

        context.profilesBox.configuration =
            configuration(
                profiles: [
                    updatedProfile
                ],
                activeProfileID:
                    updatedProfile.id
            )

        NotificationCenter.default.post(
            name:
                AppConfigurationNotification
                    .remappingRulesDidChange,
            object:
                nil
        )

        XCTAssertNil(
            sheet.validationMessageForTesting
        )

        XCTAssertTrue(
            sheet.canApplyForTesting
        )
    }

    private struct Context {
        let controller:
            MainWindowController

        let coordinator:
            HomeProfileShortcutSheetCoordinator

        let homeSession:
            HomeConfigurationEditorSession

        let profilesBox:
            HomeProfileShortcutProfilesBox

        let profilesSectionView:
            HomeProfilesSectionView

        let saveButton:
            NSButton
    }

    private func makeContext(
        profilesConfiguration:
            RemappingProfilesConfiguration,
        defaultShortcutConfiguration:
            RemappingShortcutConfiguration = .disabled
    ) throws -> Context {
        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    defaultShortcutConfiguration
            )

        let preferencesStore =
            HomeProfileShortcutPreferencesStore(
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
            HomeProfileShortcutRemappingController()

        let shortcutManager =
            HomeProfileShortcutManager()

        let globalShortcutController =
            GlobalShortcutController(
                shortcutManager:
                    shortcutManager,
                appPreferencesController:
                    preferencesController,
                configuredRulesProvider: {
                    []
                },
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

        let profilesBox =
            HomeProfileShortcutProfilesBox(
                configuration:
                    profilesConfiguration
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
                    profilesBox.configuration
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

        let coordinator =
            HomeProfileShortcutSheetCoordinator(
                mainWindowController:
                    controller,
                remappingController:
                    remappingController,
                globalShortcutController:
                    globalShortcutController,
                homeConfigurationEditorSession:
                    homeSession,
                profilesConfigurationProvider: {
                    profilesBox.configuration
                }
            )

        coordinator.start()

        let contentView =
            try XCTUnwrap(
                controller
                    .window?
                    .contentView
            )

        let profilesSectionView:
            HomeProfilesSectionView =
                try XCTUnwrap(
                    descendant(
                        of:
                            HomeProfilesSectionView.self,
                        in:
                            contentView
                    )
                )

        let saveButton:
            NSButton =
                try XCTUnwrap(
                    button(
                        withIdentifier:
                            "home.save",
                        in:
                            contentView
                    )
                )

        return Context(
            controller:
                controller,
            coordinator:
                coordinator,
            homeSession:
                homeSession,
            profilesBox:
                profilesBox,
            profilesSectionView:
                profilesSectionView,
            saveButton:
                saveButton
        )
    }

    private func close(
        _ context:
            Context
    ) {
        context.coordinator.stop()

        context.controller
            .prepareForApplicationTermination()

        context.controller
            .window?
            .orderOut(
                nil
            )
    }

    private func configuration(
        profiles:
            [RemappingProfile],
        activeProfileID:
            UUID
    ) -> RemappingProfilesConfiguration {
        RemappingProfilesConfiguration(
            profiles:
                profiles,
            activeProfileID:
                activeProfileID
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

    private func exactRule(
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
                ),
            matchingMode:
                .exact
        )
    }

    private func descendant<T: NSView>(
        of type:
            T.Type,
        in rootView:
            NSView
    ) -> T? {
        if let matchingView =
            rootView as? T
        {
            return matchingView
        }

        for subview in rootView.subviews {
            if let matchingView:
                T =
                    descendant(
                        of:
                            type,
                        in:
                            subview
                    )
            {
                return matchingView
            }
        }

        return nil
    }

    private func button(
        withIdentifier identifier:
            String,
        in rootView:
            NSView
    ) -> NSButton? {
        if let button =
            rootView as? NSButton,
           button.identifier?
               .rawValue
                == identifier
        {
            return button
        }

        for subview in rootView.subviews {
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
private final class HomeProfileShortcutProfilesBox {
    var configuration:
        RemappingProfilesConfiguration

    init(
        configuration:
            RemappingProfilesConfiguration
    ) {
        self.configuration =
            configuration
    }
}

@MainActor
private final class HomeProfileShortcutPreferencesStore:
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
private final class HomeProfileShortcutManager:
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
        registeredRegistrations
            .removeAll()
    }

    func stop() {
        unregister()
    }
}

@MainActor
private final class HomeProfileShortcutRemappingController:
    RemappingSettingsControlling
{
    private(set) var beginCaptureCallCount =
        0

    private(set) var endCaptureCallCount =
        0

    func loadConfiguredRules()
        throws -> [RemapRule]
    {
        []
    }

    func loadConfiguredRules(
        for profileID:
            UUID
    ) throws -> [RemapRule] {
        []
    }

    func replaceConfiguredRules(
        _ rules:
            [RemapRule]
    ) throws {}

    func replaceConfiguredRules(
        _ rules:
            [RemapRule],
        for profileID:
            UUID
    ) throws {}

    func beginKeyCapture() {
        beginCaptureCallCount +=
            1
    }

    func endKeyCapture() {
        endCaptureCallCount +=
            1
    }
}
