//
//  ProfileShortcutConfigurationSheetControllerTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 7/31/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileShortcutConfigurationSheetControllerTests:
    XCTestCase
{
    func testUnchangedConfigurationCannotBeApplied()
        throws
    {
        let context =
            try makeContext(
                initialOverride:
                    nil,
                defaultConfiguration:
                    .disabled
            )

        XCTAssertFalse(
            context.sheetController
                .canApplyForTesting
        )

        context.sheetController
            .applyForTesting()

        XCTAssertEqual(
            context.applyRecorder
                .attemptCount,
            0
        )

        XCTAssertFalse(
            context.sheetController
                .isFinishedForTesting
        )
    }

    func testExplicitOffIsAppliedOnlyAfterApply()
        throws
    {
        let context =
            try makeContext(
                initialOverride:
                    nil,
                defaultConfiguration:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
            )

        context.sheetController
            .setModeForTesting(
                .off
            )

        XCTAssertEqual(
            context.applyRecorder
                .attemptCount,
            0
        )

        XCTAssertTrue(
            context.sheetController
                .canApplyForTesting
        )

        context.sheetController
            .applyForTesting()

        XCTAssertEqual(
            context.applyRecorder
                .attemptCount,
            1
        )

        XCTAssertEqual(
            context.applyRecorder
                .appliedOverrides[0],
            .disabled
        )

        XCTAssertTrue(
            context.sheetController
                .isFinishedForTesting
        )
    }

    func testUseDefaultApplyPassesNilOverride()
        throws
    {
        let context =
            try makeContext(
                initialOverride:
                    .disabled,
                defaultConfiguration:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
            )

        context.sheetController
            .setModeForTesting(
                .useDefault
            )

        context.sheetController
            .applyForTesting()

        XCTAssertEqual(
            context.applyRecorder
                .attemptCount,
            1
        )

        XCTAssertNil(
            context.applyRecorder
                .appliedOverrides[0]
        )
    }

    func testCaptureSuspendsAndRestoresRuntimeComponents()
        throws
    {
        let previousConfiguration =
            makeToggleConfiguration(
                keyCode:
                    KeyCode.n
            )

        let context =
            try makeContext(
                initialOverride:
                    nil,
                defaultConfiguration:
                    previousConfiguration
            )

        context.sheetController
            .setModeForTesting(
                .toggle
            )

        context.sheetController
            .beginCaptureForTesting(
                .toggle
            )

        XCTAssertEqual(
            context.remappingController
                .beginCaptureCallCount,
            1
        )

        XCTAssertTrue(
            context.shortcutManager
                .registeredRegistrations
                .isEmpty
        )

        let capturedShortcut =
            makeShortcut(
                keyCode:
                    KeyCode.r
            )

        context.sheetController
            .captureShortcutForTesting(
                capturedShortcut
            )

        XCTAssertNil(
            context.sheetController
                .activeCaptureFieldForTesting
        )

        XCTAssertEqual(
            context.remappingController
                .endCaptureCallCount,
            1
        )

        XCTAssertEqual(
            context.shortcutManager
                .registeredRegistrations,
            previousConfiguration
                .registrations
        )

        XCTAssertEqual(
            context.sheetController
                .proposalForTesting,
            .complete(
                .toggle(
                    capturedShortcut
                )
            )
        )

        XCTAssertTrue(
            context.sheetController
                .canApplyForTesting
        )
    }

    func testCancellingCaptureDoesNotChangeOrApplyOverride()
        throws
    {
        let context =
            try makeContext(
                initialOverride:
                    nil,
                defaultConfiguration:
                    .disabled
            )

        context.sheetController
            .setModeForTesting(
                .toggle
            )

        context.sheetController
            .beginCaptureForTesting(
                .toggle
            )

        context.sheetController
            .cancelCaptureForTesting()

        XCTAssertNil(
            context.sheetController
                .activeCaptureFieldForTesting
        )

        XCTAssertEqual(
            context.remappingController
                .beginCaptureCallCount,
            1
        )

        XCTAssertEqual(
            context.remappingController
                .endCaptureCallCount,
            1
        )

        XCTAssertEqual(
            context.applyRecorder
                .attemptCount,
            0
        )
    }

    func testCancellingSheetRestoresCaptureWithoutApplying()
        throws
    {
        let context =
            try makeContext(
                initialOverride:
                    nil,
                defaultConfiguration:
                    .disabled
            )

        context.sheetController
            .setModeForTesting(
                .toggle
            )

        context.sheetController
            .beginCaptureForTesting(
                .toggle
            )

        context.sheetController
            .cancelForTesting()

        XCTAssertEqual(
            context.remappingController
                .endCaptureCallCount,
            1
        )

        XCTAssertEqual(
            context.applyRecorder
                .attemptCount,
            0
        )

        XCTAssertEqual(
            context.applyRecorder
                .dismissalCount,
            1
        )

        XCTAssertTrue(
            context.sheetController
                .isFinishedForTesting
        )
    }

    func testRegistrationRestorationFailureIsSurfaced()
        throws
    {
        let context =
            try makeContext(
                initialOverride:
                    nil,
                defaultConfiguration:
                    makeToggleConfiguration(
                        keyCode:
                            KeyCode.n
                    )
            )

        context.sheetController
            .setModeForTesting(
                .toggle
            )

        context.sheetController
            .beginCaptureForTesting(
                .toggle
            )

        context.shortcutManager
            .registrationErrors = [
                ProfileShortcutSheetTestError
                    .expected
            ]

        context.sheetController
            .captureShortcutForTesting(
                makeShortcut(
                    keyCode:
                        KeyCode.r
                )
            )

        XCTAssertFalse(
            context.sheetController
                .sheetStatusForTesting
                .isEmpty
        )

        XCTAssertEqual(
            context.remappingController
                .endCaptureCallCount,
            1
        )

        XCTAssertTrue(
            context.shortcutManager
                .registeredRegistrations
                .isEmpty
        )
    }

    func testApplyFailureKeepsSheetOpen()
        throws
    {
        let context =
            try makeContext(
                initialOverride:
                    nil,
                defaultConfiguration:
                    .disabled
            )

        context.applyRecorder.applyError =
            ProfileShortcutSheetTestError
                .expected

        context.sheetController
            .setModeForTesting(
                .off
            )

        context.sheetController
            .applyForTesting()

        XCTAssertEqual(
            context.applyRecorder
                .attemptCount,
            1
        )

        XCTAssertFalse(
            context.sheetController
                .isFinishedForTesting
        )

        XCTAssertFalse(
            context.sheetController
                .sheetStatusForTesting
                .isEmpty
        )

        XCTAssertEqual(
            context.applyRecorder
                .dismissalCount,
            0
        )
    }

    private func makeContext(
        initialOverride:
            RemappingShortcutConfiguration?,
        defaultConfiguration:
            RemappingShortcutConfiguration
    ) throws
        -> ProfileShortcutSheetTestContext
    {
        let preferences =
            AppPreferences(
                launchBehavior:
                    .alwaysOff,
                lastRemappingEnabled:
                    false,
                shortcutConfiguration:
                    defaultConfiguration
            )

        let preferencesStore =
            ProfileShortcutSheetPreferencesStore(
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
            ProfileShortcutSheetManager()

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

        try globalShortcutController
            .start()

        let remappingController =
            ProfileShortcutSheetRemappingController()

        let applyRecorder =
            ProfileShortcutSheetApplyRecorder()

        let sheetController =
            ProfileShortcutConfigurationSheetController(
                profileName:
                    "Gaming",
                shortcutConfigurationOverride:
                    initialOverride,
                defaultConfiguration:
                    defaultConfiguration,
                remappingController:
                    remappingController,
                globalShortcutController:
                    globalShortcutController,
                applyHandler: {
                    proposedOverride in

                    applyRecorder.attemptCount +=
                        1

                    if let applyError =
                        applyRecorder.applyError
                    {
                        throw applyError
                    }

                    applyRecorder
                        .appliedOverrides
                        .append(
                            proposedOverride
                        )
                },
                dismissalHandler: {
                    applyRecorder.dismissalCount +=
                        1
                }
            )

        return ProfileShortcutSheetTestContext(
            sheetController:
                sheetController,
            remappingController:
                remappingController,
            shortcutManager:
                shortcutManager,
            applyRecorder:
                applyRecorder
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
}

@MainActor
private struct ProfileShortcutSheetTestContext {
    let sheetController:
        ProfileShortcutConfigurationSheetController

    let remappingController:
        ProfileShortcutSheetRemappingController

    let shortcutManager:
        ProfileShortcutSheetManager

    let applyRecorder:
        ProfileShortcutSheetApplyRecorder
}

private nonisolated enum ProfileShortcutSheetTestError:
    Error
{
    case expected
}

@MainActor
private final class ProfileShortcutSheetApplyRecorder {
    var appliedOverrides:
        [RemappingShortcutConfiguration?] = []

    var attemptCount =
        0

    var dismissalCount =
        0

    var applyError:
        Error?
}

@MainActor
private final class ProfileShortcutSheetManager:
    GlobalShortcutRegistering
{
    private(set) var registeredRegistrations:
        [GlobalShortcutRegistration] = []

    var registrationErrors:
        [Error] = []

    private var actionHandler:
        ((GlobalShortcutAction) -> Void)?

    func register(
        _ registrations:
            [GlobalShortcutRegistration],
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void
    ) throws {
        registeredRegistrations
            .removeAll()

        self.actionHandler =
            nil

        if !registrationErrors.isEmpty {
            throw registrationErrors
                .removeFirst()
        }

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
private final class ProfileShortcutSheetPreferencesStore:
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
private final class ProfileShortcutSheetRemappingController:
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
