//
//  ForegroundApplicationRemappingTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 10/11/26.
//

import CoreGraphics
import Foundation
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ForegroundApplicationRemappingTests: XCTestCase {
    private let editor = ForegroundApplicationScope.Application(
        bundleIdentifier: "com.example.editor",
        displayName: "Editor"
    )

    func testScopeModesAndLegacyPreferences() throws {
        let legacy = try JSONDecoder().decode(AppPreferences.self, from: Data("{}".utf8))
        XCTAssertEqual(legacy.foregroundApplicationScope, .unrestricted)

        var preferences = legacy
        preferences.foregroundApplicationScope = .init(
            mode: .onlySelectedApplications,
            applications: [editor]
        )
        let data = try JSONEncoder().encode(preferences)
        XCTAssertEqual(try JSONDecoder().decode(AppPreferences.self, from: data), preferences)

        var scope = preferences.foregroundApplicationScope
        XCTAssertTrue(scope.allowsRemapping(in: editor.bundleIdentifier))
        XCTAssertFalse(scope.allowsRemapping(in: "com.example.other"))
        XCTAssertFalse(scope.allowsRemapping(in: nil))

        scope = .init(excludedApplications: [editor])
        XCTAssertFalse(scope.allowsRemapping(in: editor.bundleIdentifier))
        XCTAssertTrue(scope.allowsRemapping(in: nil))

        scope = .init(includedApplications: [editor])
        XCTAssertTrue(scope.allowsRemapping(in: editor.bundleIdentifier))
        XCTAssertTrue(scope.observesForegroundApplication)
        XCTAssertEqual(scope.remappingOverride(in: editor.bundleIdentifier), true)
        XCTAssertNil(scope.remappingOverride(in: "com.example.other"))

        scope = .init(mode: .onlySelectedApplications)
        XCTAssertFalse(scope.allowsRemapping(in: editor.bundleIdentifier))
        XCTAssertFalse(scope.observesForegroundApplication)
    }

    func testBothListsUseExplicitOverridesAndTheOtherAppsChoice() throws {
        let other = ForegroundApplicationScope.Application(
            bundleIdentifier: "com.example.browser",
            displayName: "Browser"
        )
        var scope = ForegroundApplicationScope(
            allowsOtherApplications: false,
            includedApplications: [editor],
            excludedApplications: [other]
        )

        try scope.validate()
        XCTAssertTrue(scope.allowsRemapping(in: editor.bundleIdentifier))
        XCTAssertFalse(scope.allowsRemapping(in: other.bundleIdentifier))
        XCTAssertFalse(scope.allowsRemapping(in: "com.example.unlisted"))

        scope.allowsOtherApplications = true
        XCTAssertTrue(scope.allowsRemapping(in: "com.example.unlisted"))
        XCTAssertFalse(scope.allowsRemapping(in: other.bundleIdentifier))
        let data = try JSONEncoder().encode(scope)
        XCTAssertEqual(try JSONDecoder().decode(ForegroundApplicationScope.self, from: data), scope)
    }

    func testConflictingAdditionRemainsInTheDraftAndValidationBlocksSaving() throws {
        let initial = ForegroundApplicationScope(includedApplications: [editor])
        let draft = initial.adding([editor, editor], to: .excluded)

        XCTAssertEqual(draft.includedApplications, [editor])
        XCTAssertEqual(draft.excludedApplications, [editor])
        XCTAssertNotNil(draft.validationMessage)
        XCTAssertThrowsError(try draft.validate())
        XCTAssertTrue(initial.excludedApplications.isEmpty)

        var resolved = draft
        resolved.includedApplications.removeAll()
        XCTAssertNil(resolved.validationMessage)
        XCTAssertNoThrow(try resolved.validate())
        XCTAssertFalse(resolved.allowsRemapping(in: editor.bundleIdentifier))
    }

    func testLegacyScopeMigrationPreservesEveryMode() throws {
        for mode in ["allApplications", "onlySelectedApplications", "exceptSelectedApplications"] {
            let legacy = try JSONSerialization.data(withJSONObject: [
                "mode": mode,
                "applications": [["bundleIdentifier": editor.bundleIdentifier, "displayName": editor.displayName]]
            ])
            let decoded = try JSONDecoder().decode(ForegroundApplicationScope.self, from: legacy)
            XCTAssertEqual(decoded.allowsOtherApplications, mode != "onlySelectedApplications")
            XCTAssertEqual(
                decoded.includedApplications,
                mode == "onlySelectedApplications" ? [editor] : []
            )
            XCTAssertEqual(
                decoded.excludedApplications,
                mode == "exceptSelectedApplications" ? [editor] : []
            )
        }
    }

    func testConflictingHomeDraftCanBeUndoneAndRedone() {
        let profiles = ControllerMockRulesStore().configuration
        let session = HomeConfigurationEditorSession(snapshot: .init(
            profilesConfiguration: profiles,
            launchBehavior: .alwaysOff,
            shortcutConfiguration: .disabled
        ))
        let conflicting = ForegroundApplicationScope(
            includedApplications: [editor],
            excludedApplications: [editor]
        )

        session.setForegroundApplicationScope(conflicting)
        XCTAssertTrue(session.hasUnsavedChanges)
        XCTAssertNotNil(session.draft.foregroundApplicationScope.validationMessage)
        session.undo()
        XCTAssertFalse(session.hasUnsavedChanges)
        XCTAssertNil(session.draft.foregroundApplicationScope.validationMessage)
        session.redo()
        XCTAssertEqual(session.draft.foregroundApplicationScope, conflicting)
        XCTAssertNotNil(session.draft.foregroundApplicationScope.validationMessage)
    }

    func testConflictingScopeIsRejectedWhenDecodingPreferences() throws {
        let invalid = ForegroundApplicationScope(
            includedApplications: [editor],
            excludedApplications: [editor]
        )
        let data = try JSONEncoder().encode(invalid)
        XCTAssertThrowsError(try JSONDecoder().decode(ForegroundApplicationScope.self, from: data))
    }

    func testApplicationSwitchesGateRemappingWithoutRestartingOrLoadingRules() {
        let store = ControllerMockRulesStore()
        let tap = ControllerMockEventTapManager()
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: store,
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { "com.example.other" }
        )

        controller.setForegroundApplicationScope(
            .init(mode: .onlySelectedApplications, applications: [editor])
        )

        controller.enable()
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)

        controller.foregroundApplicationDidActivate(bundleIdentifier: editor.bundleIdentifier)
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertTrue(tap.foregroundApplicationAllowsRemapping)

        controller.beginKeyCapture()
        controller.foregroundApplicationDidActivate(bundleIdentifier: nil)
        controller.endKeyCapture()
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
        XCTAssertEqual(tap.startCallCount, 1)
        XCTAssertEqual(store.loadCallCount, 1)
        XCTAssertEqual(store.saveCallCount, 0)

        controller.toggle()
        XCTAssertFalse(controller.isManualRemappingEnabled)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertTrue(tap.isRunning)
        controller.foregroundApplicationDidActivate(bundleIdentifier: editor.bundleIdentifier)
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertFalse(controller.isManualRemappingEnabled)
        XCTAssertEqual(tap.startCallCount, 1)
    }

    func testIncludedAppEnablesFromManualOffAndRestoresItWithoutReloading() {
        let store = ControllerMockRulesStore()
        let tap = ControllerMockEventTapManager()
        var activeApp: String? = "com.example.other"
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: store,
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { activeApp }
        )
        controller.setForegroundApplicationScope(.init(includedApplications: [editor]))
        XCTAssertEqual(controller.state, .disabled)
        XCTAssertFalse(controller.isManualRemappingEnabled)
        XCTAssertEqual(store.loadCallCount, 0)

        activeApp = editor.bundleIdentifier
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertFalse(controller.isManualRemappingEnabled)
        XCTAssertTrue(tap.foregroundApplicationAllowsRemapping)

        activeApp = "com.example.other"
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
        XCTAssertFalse(controller.isManualRemappingEnabled)

        activeApp = editor.bundleIdentifier
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertEqual(tap.startCallCount, 1)
        XCTAssertEqual(store.loadCallCount, 1)
        XCTAssertEqual(store.saveCallCount, 0)
    }

    func testExcludedAppRestoresManualOnAndDoesNotChangeTheManualPreference() {
        let tap = ControllerMockEventTapManager()
        let store = ControllerMockRulesStore()
        var activeApp: String? = "com.example.other"
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: store,
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { activeApp }
        )
        controller.setForegroundApplicationScope(.init(excludedApplications: [editor]))
        controller.enable()
        XCTAssertEqual(controller.state, .enabled)

        activeApp = editor.bundleIdentifier
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)

        activeApp = "com.example.other"
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertTrue(tap.foregroundApplicationAllowsRemapping)
        XCTAssertEqual(tap.startCallCount, 1)
        XCTAssertEqual(store.loadCallCount, 1)
    }

    func testUnlistedAppsCanStayOffWhileIncludedAppsEnableAutomatically() {
        let tap = ControllerMockEventTapManager()
        var activeApp: String? = "com.example.other"
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { activeApp }
        )
        controller.setForegroundApplicationScope(.init(
            allowsOtherApplications: false,
            includedApplications: [editor]
        ))
        controller.enable()
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)

        activeApp = editor.bundleIdentifier
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .enabled)
        activeApp = "com.example.other"
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
    }

    func testAutomaticActivationNeverPromptsForMissingPermission() {
        let permission = ControllerMockPermissionService(isGranted: false)
        let tap = ControllerMockEventTapManager()
        var activeApp: String? = "com.example.other"
        let controller = RemappingController(
            permissionService: permission,
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { activeApp }
        )
        controller.setForegroundApplicationScope(.init(includedApplications: [editor]))
        activeApp = editor.bundleIdentifier
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertEqual(controller.state, .permissionRequired)
        XCTAssertEqual(permission.requestAccessCallCount, 0)
        XCTAssertFalse(tap.isRunning)

        permission.isGranted = true
        controller.refreshAccessibilityPermission()
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertFalse(controller.isManualRemappingEnabled)
    }

    func testRemovingAutomationReleasesThePausedTapWhenManualIsOff() {
        let tap = ControllerMockEventTapManager()
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { self.editor.bundleIdentifier }
        )
        controller.setForegroundApplicationScope(.init(includedApplications: [editor]))
        XCTAssertEqual(controller.state, .enabled)
        controller.setForegroundApplicationScope(.unrestricted)
        XCTAssertEqual(controller.state, .disabled)
        XCTAssertFalse(tap.isRunning)
        XCTAssertFalse(controller.isManualRemappingEnabled)
    }

    func testToggleCanRetryAfterTheManualSettingFailedToStart() {
        let permission = ControllerMockPermissionService(isGranted: false)
        let controller = RemappingController(
            permissionService: permission,
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: ControllerMockEventTapManager()
        )
        controller.enable()
        XCTAssertEqual(controller.state, .permissionRequired)
        permission.isGranted = true
        controller.toggle()
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertTrue(controller.isManualRemappingEnabled)
    }

    func testManualSettingChangesAreReportedWhileAnAppRuleKeepsRemappingOn() {
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: ControllerMockEventTapManager(),
            foregroundApplicationBundleIdentifierProvider: { self.editor.bundleIdentifier }
        )
        controller.setForegroundApplicationScope(.init(includedApplications: [editor]))
        var manualSettings: [Bool] = []
        controller.onStateChange = { _ in
            manualSettings.append(controller.isManualRemappingEnabled)
        }
        controller.enable()
        controller.disable()
        XCTAssertEqual(manualSettings, [true, false])
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertFalse(controller.isManualRemappingEnabled)

        controller.stop()
        XCTAssertEqual(controller.state, .disabled)
        controller.onStateChange = nil
    }

    func testTemporaryManualActivationIsExplicitAndResetsWhenTheAppChanges() {
        let store = ControllerMockRulesStore()
        let tap = ControllerMockEventTapManager()
        var activeApp: String? = "com.example.first"
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: store,
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { activeApp }
        )
        controller.setForegroundApplicationScope(.init(
            allowsOtherApplications: false,
            allowsManualActivationForOtherApplications: true
        ))
        XCTAssertEqual(controller.state, .disabled)
        XCTAssertTrue(controller.usesTemporaryManualActivation)
        XCTAssertFalse(controller.isManualControlOn)
        XCTAssertEqual(store.loadCallCount, 0)

        controller.toggle()
        XCTAssertEqual(controller.state, .enabled)
        XCTAssertTrue(controller.isManualControlOn)
        XCTAssertFalse(controller.isManualRemappingEnabled)

        // Another activation for the same app can be another one of its windows.
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertTrue(controller.isManualControlOn)
        XCTAssertEqual(controller.state, .enabled)

        activeApp = "com.example.second"
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertFalse(controller.isManualControlOn)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)

        activeApp = "com.example.first"
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertFalse(controller.isManualControlOn)
        controller.enable()
        XCTAssertTrue(controller.isManualControlOn)
        XCTAssertEqual(controller.state, .enabled)
        controller.disable()
        XCTAssertFalse(controller.isManualControlOn)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertEqual(tap.startCallCount, 1)
        XCTAssertEqual(store.loadCallCount, 1)
        XCTAssertEqual(store.saveCallCount, 0)
    }

    func testTemporaryManualActivationPreservesTheManualSettingAndExcludedApps() {
        let tap = ControllerMockEventTapManager()
        var activeApp: String? = "com.example.other"
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { activeApp }
        )
        controller.enable()
        let scope = ForegroundApplicationScope(
            allowsOtherApplications: false,
            allowsManualActivationForOtherApplications: true,
            excludedApplications: [editor]
        )
        controller.setForegroundApplicationScope(scope)
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertFalse(controller.isManualControlOn)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)

        controller.enable()
        XCTAssertTrue(controller.isManualControlOn)
        controller.disable()
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertFalse(controller.isManualControlOn)

        activeApp = editor.bundleIdentifier
        controller.foregroundApplicationDidActivate(bundleIdentifier: activeApp)
        XCTAssertFalse(controller.usesTemporaryManualActivation)
        controller.enable()
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)

        controller.setForegroundApplicationScope(.unrestricted)
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertEqual(controller.state, .enabled)
    }

    func testManualActivationChoiceRoundTripsAndOlderScopesDefaultToBlocked() throws {
        let choice = ForegroundApplicationScope(
            allowsOtherApplications: false,
            allowsManualActivationForOtherApplications: true,
            includedApplications: [editor]
        )
        let encoded = try JSONEncoder().encode(choice)
        let restored = try JSONDecoder().decode(ForegroundApplicationScope.self, from: encoded)
        XCTAssertEqual(restored, choice)
        XCTAssertTrue(restored.observesForegroundApplication)
        XCTAssertTrue(restored.permitsTemporaryManualActivation(in: "com.example.other"))
        XCTAssertFalse(restored.permitsTemporaryManualActivation(in: editor.bundleIdentifier))
        XCTAssertFalse(restored.permitsTemporaryManualActivation(in: nil))

        let older = Data("""
            {"allowsOtherApplications":false,"includedApplications":[],"excludedApplications":[]}
            """.utf8)
        let migrated = try JSONDecoder().decode(ForegroundApplicationScope.self, from: older)
        XCTAssertFalse(migrated.allowsManualActivationForOtherApplications)
        XCTAssertFalse(migrated.permitsTemporaryManualActivation)
    }

    func testRestoringManualOnAtLaunchDoesNotGrantTemporaryActivation() {
        let controller = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: ControllerMockEventTapManager(),
            foregroundApplicationBundleIdentifierProvider: { "com.example.other" }
        )
        controller.setForegroundApplicationScope(.init(
            allowsOtherApplications: false,
            allowsManualActivationForOtherApplications: true
        ))
        controller.restoreManualSettingAtLaunch(true)
        XCTAssertTrue(controller.isManualRemappingEnabled)
        XCTAssertFalse(controller.isManualControlOn)
        XCTAssertEqual(controller.state, .pausedForForegroundApplication)
        controller.enable()
        XCTAssertTrue(controller.isManualControlOn)
        XCTAssertEqual(controller.state, .enabled)
    }

    func testFocusChangePreservesReleaseAndLeavesUntrackedPressNative() throws {
        let engine = RemappingEngine()
        engine.replaceRules([RemapRule(sourceKeyCode: KeyCode.v, destinationKeyCode: KeyCode.w)])
        let tap = EventTapManager(remappingEngine: engine)

        let down = try keyboardEvent(isDown: true)
        XCTAssertNotNil(tap.handle(eventType: .keyDown, event: down))
        XCTAssertEqual(keyCode(of: down), Int64(KeyCode.w))

        tap.setForegroundApplicationAllowsRemapping(false)
        let suppressedRepeat = try keyboardEvent(isDown: true, isRepeat: true)
        XCTAssertNil(tap.handle(eventType: .keyDown, event: suppressedRepeat))

        let up = try keyboardEvent(isDown: false)
        XCTAssertNotNil(tap.handle(eventType: .keyUp, event: up))
        XCTAssertEqual(keyCode(of: up), Int64(KeyCode.w))

        let nativeDown = try keyboardEvent(isDown: true)
        XCTAssertNotNil(tap.handle(eventType: .keyDown, event: nativeDown))
        XCTAssertEqual(keyCode(of: nativeDown), Int64(KeyCode.v))

        tap.setForegroundApplicationAllowsRemapping(true)
        let nativeRepeat = try keyboardEvent(isDown: true, isRepeat: true)
        XCTAssertNotNil(tap.handle(eventType: .keyDown, event: nativeRepeat))
        XCTAssertEqual(keyCode(of: nativeRepeat), Int64(KeyCode.v))

        let nativeUp = try keyboardEvent(isDown: false)
        XCTAssertNotNil(tap.handle(eventType: .keyUp, event: nativeUp))
        XCTAssertEqual(keyCode(of: nativeUp), Int64(KeyCode.v))

        let nextDown = try keyboardEvent(isDown: true)
        XCTAssertNotNil(tap.handle(eventType: .keyDown, event: nextDown))
        XCTAssertEqual(keyCode(of: nextDown), Int64(KeyCode.w))
    }

    private func keyboardEvent(isDown: Bool, isRepeat: Bool = false) throws -> CGEvent {
        let event = try XCTUnwrap(CGEvent(keyboardEventSource: nil, virtualKey: KeyCode.v, keyDown: isDown))
        event.flags = []
        event.setIntegerValueField(.keyboardEventAutorepeat, value: isRepeat ? 1 : 0)
        return event
    }

    private func keyCode(of event: CGEvent) -> Int64 {
        event.getIntegerValueField(.keyboardEventKeycode)
    }
}
