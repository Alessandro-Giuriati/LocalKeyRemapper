//
//  ProfileShortcutMemoryPresentationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileShortcutMemoryPresentationTests:
    XCTestCase
{
    func testUseDefaultDraftRestoresRememberedToggle()
    {
        let rememberedToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        var draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    nil,
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        toggleShortcut:
                            rememberedToggle
                    )
            )

        XCTAssertEqual(
            draft.mode,
            .useDefault
        )

        draft.mode =
            .toggle

        XCTAssertEqual(
            draft.proposal,
            .complete(
                .toggle(
                    rememberedToggle
                )
            )
        )
    }

    func testOffDraftRestoresRememberedSeparateShortcuts()
    {
        let rememberedEnable =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let rememberedDisable =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        var draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .disabled,
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        enableShortcut:
                            rememberedEnable,
                        disableShortcut:
                            rememberedDisable
                    )
            )

        XCTAssertEqual(
            draft.mode,
            .off
        )

        draft.mode =
            .separate

        XCTAssertEqual(
            draft.proposal,
            .complete(
                .separate(
                    enable:
                        rememberedEnable,
                    disable:
                        rememberedDisable
                )
            )
        )
    }

    func testCurrentToggleOverrideWinsOverStaleToggleMemory()
    {
        let currentToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let staleToggle =
            makeShortcut(
                keyCode:
                    KeyCode.n
            )

        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .toggle(
                        currentToggle
                    ),
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        toggleShortcut:
                            staleToggle
                    )
            )

        XCTAssertEqual(
            draft.mode,
            .toggle
        )

        XCTAssertEqual(
            draft.toggleShortcut,
            currentToggle
        )
    }

    func testCurrentSeparateOverrideWinsOverStaleSeparateMemory()
    {
        let currentEnable =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let currentDisable =
            makeShortcut(
                keyCode:
                    KeyCode.d
            )

        let draft =
            ProfileShortcutConfigurationDraft(
                shortcutConfigurationOverride:
                    .separate(
                        enable:
                            currentEnable,
                        disable:
                            currentDisable
                    ),
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        enableShortcut:
                            makeShortcut(
                                keyCode:
                                    KeyCode.r
                            ),
                        disableShortcut:
                            makeShortcut(
                                keyCode:
                                    KeyCode.n
                            )
                    )
            )

        XCTAssertEqual(
            draft.enableShortcut,
            currentEnable
        )

        XCTAssertEqual(
            draft.disableShortcut,
            currentDisable
        )
    }

    func testEditorViewRestoresRememberedToggleFromOff()
    {
        let rememberedToggle =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        let view =
            ProfileShortcutConfigurationEditorView(
                shortcutConfigurationOverride:
                    .disabled,
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        toggleShortcut:
                            rememberedToggle
                    ),
                defaultConfiguration:
                    .disabled
            )

        view.setModeForTesting(
            .toggle
        )

        XCTAssertEqual(
            view.proposal,
            .complete(
                .toggle(
                    rememberedToggle
                )
            )
        )

        XCTAssertTrue(
            view.canApply
        )
    }

    func testSheetRestoresRememberedSeparateFromUseDefault()
        throws
    {
        let rememberedEnable =
            makeShortcut(
                keyCode:
                    KeyCode.e
            )

        let rememberedDisable =
            makeShortcut(
                keyCode:
                    KeyCode.d
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
            ProfileShortcutMemoryPreferencesStore(
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

        let shortcutController =
            GlobalShortcutController(
                shortcutManager:
                    ProfileShortcutMemoryManager(),
                appPreferencesController:
                    preferencesController,
                configuredRulesProvider: {
                    []
                },
                actionHandler: {
                    _ in
                }
            )

        let sheet =
            ProfileShortcutConfigurationSheetController(
                profileName:
                    "Gaming",
                shortcutConfigurationOverride:
                    nil,
                shortcutMemory:
                    RemappingProfileShortcutMemory(
                        enableShortcut:
                            rememberedEnable,
                        disableShortcut:
                            rememberedDisable
                    ),
                defaultConfiguration:
                    .disabled,
                remappingController:
                    ProfileShortcutMemoryRemappingController(),
                globalShortcutController:
                    shortcutController,
                applyHandler: {
                    _ in
                }
            )

        sheet.setModeForTesting(
            .separate
        )

        XCTAssertEqual(
            sheet.proposalForTesting,
            .complete(
                .separate(
                    enable:
                        rememberedEnable,
                    disable:
                        rememberedDisable
                )
            )
        )

        XCTAssertTrue(
            sheet.canApplyForTesting
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

@MainActor
private final class ProfileShortcutMemoryPreferencesStore:
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
private final class ProfileShortcutMemoryManager:
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
private final class ProfileShortcutMemoryRemappingController:
    RemappingSettingsControlling
{
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

    func beginKeyCapture() {}

    func endKeyCapture() {}
}
