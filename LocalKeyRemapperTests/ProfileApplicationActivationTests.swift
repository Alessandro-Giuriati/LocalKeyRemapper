//
//  ProfileApplicationActivationTests.swift
//  LocalKeyRemapperTests
//
//  Created by Alessandro Giuriati on 11/11/26.
//

import AppKit
import XCTest

@testable import LocalKeyRemapper

@MainActor
final class ProfileApplicationActivationTests: XCTestCase {
    private let app = ForegroundApplicationScope.Application(bundleIdentifier: "com.example.editor", displayName: "Editor")

    private func profile(enablesRemapping: Bool = false) -> RemappingProfile {
        RemappingProfile(name: "Editor", applicationActivation: .init(applications: [app], enablesRemapping: enablesRemapping))
    }

    private func configuration(_ profiles: [RemappingProfile]) -> RemappingProfilesConfiguration {
        .init(profiles: profiles, activeProfileID: profiles[0].id)
    }

    func testOldProfilesDecodeWithoutAssignmentsAndNewSettingsRoundTrip() throws {
        let original = profile(enablesRemapping: true)
        let data = try JSONEncoder().encode(original)
        XCTAssertEqual(try JSONDecoder().decode(RemappingProfile.self, from: data), original)
        var payload = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        payload.removeValue(forKey: "applicationActivation")
        let oldData = try JSONSerialization.data(withJSONObject: payload)
        let migrated = try JSONDecoder().decode(RemappingProfile.self, from: oldData)
        XCTAssertEqual(migrated.applicationActivation, .disabled)
        XCTAssertEqual(migrated.id, original.id)
        XCTAssertEqual(migrated.rules, original.rules)
    }

    func testAssignmentsPersistInTheProfileStore() throws {
        let suite = "ProfileApplicationActivationTests." + UUID().uuidString
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsRemappingProfilesStore(userDefaults: defaults)
        let config = configuration([profile(enablesRemapping: true)])
        try store.saveConfiguration(config)
        XCTAssertEqual(try store.loadConfiguration(), config)
    }

    func testAddingAppsDeduplicatesByBundleIdentity() {
        let renamed = ForegroundApplicationScope.Application(bundleIdentifier: app.bundleIdentifier, displayName: "Renamed")
        XCTAssertEqual(ProfileApplicationActivation.disabled.adding([app, app, renamed]).applications, [app])
    }

    func testAssignmentsToDifferentProfilesBlockValidation() {
        let first = profile()
        var second = profile()
        second.name = "Second"
        XCTAssertThrowsError(try RemappingProfilesConfigurationValidator().validate(configuration([first, second])))
        second.applicationActivation = .disabled
        XCTAssertNoThrow(try RemappingProfilesConfigurationValidator().validate(configuration([first, second])))
    }

    func testInactiveProfileEntriesPersistAndAreIgnoredByActivationAndConflicts() throws {
        var first = profile(enablesRemapping: true)
        var second = profile(enablesRemapping: true)
        second.name = "Second"
        second.applicationActivation.applications[0].isEnabled = false
        let config = configuration([first, second])
        let data = try JSONEncoder().encode(config)
        let restored = try JSONDecoder().decode(RemappingProfilesConfiguration.self, from: data)
        XCTAssertEqual(restored, config)
        try ProfileApplicationActivation.validate(restored.profiles)

        let inactive = second.applicationActivation.applications[0]
        let disabledExclusion = ForegroundApplicationScope(excludedApplications: [inactive])
        let conflicts = ProfileApplicationConflicts(profiles: restored.profiles, scope: disabledExclusion)
        XCTAssertFalse(conflicts.affects(first.applicationActivation))
        XCTAssertNil(conflicts.globalWarning(for: first))
        let activeExclusion = ForegroundApplicationScope(excludedApplications: [app])
        let exclusionConflicts = ProfileApplicationConflicts(profiles: restored.profiles, scope: activeExclusion)
        XCTAssertTrue(exclusionConflicts.affects(first.applicationActivation))
        XCTAssertFalse(exclusionConflicts.affects(second.applicationActivation))

        var selected: [UUID] = []
        var overrides: [Bool?] = []
        let controller = ProfileApplicationActivationController(
            activateProfile: { selected.append($0) },
            applyRemappingOverride: { _, override, _ in overrides.append(override) },
            reportFailure: { _, _ in XCTFail("Unexpected failure") }
        )
        controller.load(restored)
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(selected, [first.id])
        XCTAssertEqual(overrides, [true])

        first.applicationActivation.applications[0].isEnabled = false
        controller.load(configuration([first, second]))
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(selected, [first.id])
        XCTAssertEqual(overrides, [true, nil])
        XCTAssertFalse(controller.foregroundApplicationHasAssignment)
    }

    func testDuplicateWarningListsEveryOwnerAndSkipsUnrelatedEditors() throws {
        let first = profile()
        var second = profile()
        second.name = "Second"
        var third = profile()
        third.name = "Third"
        let unrelated = RemappingProfile(name: "Unrelated")
        let profiles = [first, second, third, unrelated]
        let message = try XCTUnwrap(ProfileApplicationActivation.validationMessage(for: profiles))
        XCTAssertTrue(message.contains("3 profiles"))

        for owner in [first, second, third] {
            XCTAssertTrue(message.contains(owner.name))
            XCTAssertEqual(ProfileApplicationActivation.validationMessage(for: profiles, involving: owner.id), message)
        }
        XCTAssertNil(ProfileApplicationActivation.validationMessage(for: profiles, involving: unrelated.id))
    }

    func testEditorUndoRedoAndDuplicateKeepAssignmentsIndependent() throws {
        let original = RemappingProfile(name: "Editor")
        let session = HomeConfigurationEditorSession(snapshot: .init(
            profilesConfiguration: configuration([original]), launchBehavior: .alwaysOff, shortcutConfiguration: .disabled
        ))
        let activation = ProfileApplicationActivation(applications: [app], enablesRemapping: true)
        let date = original.updatedAt.addingTimeInterval(10)
        try session.setApplicationActivation(activation, for: original.id, timestamp: date)
        XCTAssertTrue(session.hasUnsavedChanges)
        XCTAssertEqual(session.draft.profiles[0].updatedAt, date)
        XCTAssertEqual(session.historyEntryCount, 1)
        try session.setApplicationActivation(activation, for: original.id)
        XCTAssertEqual(session.historyEntryCount, 1)
        session.undo()
        XCTAssertEqual(session.draft.profiles[0], original)
        session.redo()
        XCTAssertEqual(session.draft.profiles[0].applicationActivation, activation)
        let duplicate = try session.duplicateProfile(id: original.id)
        XCTAssertEqual(duplicate.applicationActivation, .disabled)
        XCTAssertNoThrow(try ProfileApplicationActivation.validate(session.draft.profiles))
        let missing = UUID()
        XCTAssertThrowsError(try session.setApplicationActivation(activation, for: missing))
    }

    func testHomeMergeKeepsAppDraftAndLatestSavedRules() {
        let saved = RemappingProfile(name: "Saved", rules: [RemapRule(sourceKeyCode: KeyCode.v, destinationKeyCode: KeyCode.w)])
        var draft = saved
        draft.rules = []
        draft.applicationActivation = .init(applications: [app], enablesRemapping: true)
        let merged = HomeProfilesConfigurationMerger.merging(homeDraft: configuration([draft]), persisted: configuration([saved]))
        XCTAssertEqual(merged.profiles[0].applicationActivation, draft.applicationActivation)
        XCTAssertEqual(merged.profiles[0].rules, saved.rules)
    }

    func testActivationPrecedesAutomaticEnableAndDuplicateNotificationsAreIgnored() {
        let profile = profile(enablesRemapping: true)
        var events: [String] = []
        var assignments: [Bool] = []
        let controller = ProfileApplicationActivationController(
            activateProfile: { id in
                XCTAssertEqual(id, profile.id)
                events.append("activate")
            },
            applyRemappingOverride: { _, value, hasAssignment in
                events.append(value == true ? "enable" : "manual")
                assignments.append(hasAssignment)
            },
            reportFailure: { _, _ in XCTFail("Unexpected failure") }
        )
        controller.load(configuration([profile]))
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(events, ["activate", "enable"])
        controller.foregroundApplicationDidActivate(bundleIdentifier: "com.example.other")
        XCTAssertEqual(events, ["activate", "enable", "manual"])
        controller.foregroundApplicationDidActivate(bundleIdentifier: nil)
        XCTAssertEqual(events.last, "manual")
        XCTAssertEqual(assignments, [true, false, false])
    }

    func testProfileSelectionAloneUsesTheGeneralRemappingSetting() {
        var activations = 0
        let controller = ProfileApplicationActivationController(
            activateProfile: { _ in activations += 1 },
            applyRemappingOverride: { _, value, _ in XCTAssertNil(value) },
            reportFailure: { _, _ in XCTFail("Unexpected failure") }
        )
        controller.load(configuration([profile()]))
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(activations, 1)
    }

    func testFailedActivationKeepsRemappingOffAndRetriesAfterFocusChanges() {
        enum Failure: Error { case rejected }
        var failures = 0
        var activations = 0
        var overrides: [Bool?] = []
        let controller = ProfileApplicationActivationController(
            activateProfile: { _ in activations += 1; throw Failure.rejected },
            applyRemappingOverride: { _, value, _ in overrides.append(value) },
            reportFailure: { _, _ in failures += 1 }
        )
        controller.load(configuration([profile(enablesRemapping: true)]))
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(activations, 1)
        XCTAssertEqual(overrides, [false])
        controller.foregroundApplicationDidActivate(bundleIdentifier: "other")
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(activations, 2)
        XCTAssertEqual(failures, 2)
        XCTAssertEqual(overrides, [false, nil, false])
    }

    func testNewlyCommittedAssignmentsReplaceOldIndexEvenForTheSameApp() {
        let first = profile()
        let second = RemappingProfile(name: "Second")
        var selected: [UUID] = []
        let controller = ProfileApplicationActivationController(
            activateProfile: { selected.append($0) }, applyRemappingOverride: { _, _, _ in }, reportFailure: { _, _ in }
        )
        controller.load(configuration([first, second]))
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        var updatedFirst = first
        updatedFirst.applicationActivation = .disabled
        var updatedSecond = second
        updatedSecond.applicationActivation = first.applicationActivation
        controller.load(configuration([updatedFirst, updatedSecond]))
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(selected, [first.id, second.id])
        controller.load(configuration([updatedFirst, second]))
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(selected, [first.id, second.id])
    }

    func testTemporaryProfileSurvivesHomeAndReloadAndExpiresOnAnotherApp() {
        let assignedProfile = profile(enablesRemapping: true)
        let config = configuration([assignedProfile])
        let interfaceID = "com.example.remapper"
        var events: [String] = []
        let controller = ProfileApplicationActivationController(
            interfaceBundleIdentifier: interfaceID,
            restoreTemporaryProfile: { events.append("restore") },
            activateProfile: { _ in events.append("assigned profile") },
            applyRemappingOverride: { _, value, _ in events.append(value == true ? "automatic" : "manual") },
            reportFailure: { _, _ in XCTFail("Unexpected failure") }
        )
        controller.load(config)
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        controller.foregroundApplicationDidActivate(bundleIdentifier: interfaceID, hasTemporaryProfile: true)
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier, hasTemporaryProfile: true)
        XCTAssertEqual(events, ["assigned profile", "automatic"])
        XCTAssertTrue(controller.foregroundApplicationHasAssignment)

        controller.load(config)
        controller.foregroundApplicationDidActivate(bundleIdentifier: interfaceID, hasTemporaryProfile: true)
        XCTAssertEqual(events, ["assigned profile", "automatic", "automatic"])
        controller.foregroundApplicationDidActivate(bundleIdentifier: "other", hasTemporaryProfile: true)
        XCTAssertEqual(Array(events.suffix(2)), ["restore", "manual"])
        XCTAssertFalse(controller.foregroundApplicationHasAssignment)
        controller.foregroundApplicationDidActivate(bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(Array(events.suffix(2)), ["assigned profile", "automatic"])
    }

    func testTemporaryManualEnableInHomeTargetsTheLastExternalApp() {
        let config = configuration([RemappingProfile(name: "Manual")])
        let interfaceID = "com.example.remapper"
        let tap = ControllerMockEventTapManager()
        var frontmostID = app.bundleIdentifier
        let runtime = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(),
            eventTapManager: tap,
            interfaceBundleIdentifier: interfaceID,
            foregroundApplicationBundleIdentifierProvider: { frontmostID }
        )
        let activation = ProfileApplicationActivationController(
            interfaceBundleIdentifier: interfaceID,
            activateProfile: { _ in XCTFail("No app has an assigned profile") },
            applyRemappingOverride: { bundleIdentifier, value, hasAssignment in
                runtime.setProfileApplicationRemappingOverride(
                    value, bundleIdentifier: bundleIdentifier, hasAssignedProfile: hasAssignment
                )
            },
            reportFailure: { _, _ in XCTFail("Unexpected failure") }
        )
        func focus(_ bundleIdentifier: String) {
            frontmostID = bundleIdentifier
            activation.foregroundApplicationDidActivate(bundleIdentifier: bundleIdentifier)
        }

        activation.load(config)
        focus(app.bundleIdentifier)
        focus(interfaceID)

        // Save Allow Manual Activation while Home is already in front.
        runtime.setForegroundApplicationScope(.init(
            allowsOtherApplications: false,
            allowsManualActivationForOtherApplications: true
        ))
        activation.load(config)
        focus(interfaceID)
        XCTAssertTrue(runtime.usesTemporaryManualActivation)
        XCTAssertFalse(runtime.isManualControlOn)

        runtime.enable()
        focus(app.bundleIdentifier)
        XCTAssertTrue(tap.foregroundApplicationAllowsRemapping)
        XCTAssertFalse(runtime.isManualRemappingEnabled)
        runtime.toggle()
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)

        runtime.enable()
        focus(interfaceID)
        focus(app.bundleIdentifier)
        XCTAssertTrue(tap.foregroundApplicationAllowsRemapping)

        focus("com.example.other")
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
        focus(app.bundleIdentifier)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
        XCTAssertFalse(runtime.isManualRemappingEnabled)
    }

    func testTemporaryOffOverridesAutomaticEnableUntilAppChanges() {
        let tap = ControllerMockEventTapManager()
        var frontmostID = app.bundleIdentifier
        let runtime = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(), rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(), eventTapManager: tap,
            foregroundApplicationBundleIdentifierProvider: { frontmostID }
        )
        runtime.setProfileApplicationRemappingOverride(true, bundleIdentifier: app.bundleIdentifier, hasAssignedProfile: true)
        XCTAssertTrue(runtime.isManualControlOn)
        frontmostID = "com.example.remapper"
        runtime.toggle()
        XCTAssertFalse(runtime.isManualControlOn)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
        XCTAssertFalse(runtime.isManualRemappingEnabled)

        runtime.setProfileApplicationRemappingOverride(true, bundleIdentifier: app.bundleIdentifier, hasAssignedProfile: true)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
        frontmostID = "other"
        runtime.setProfileApplicationRemappingOverride(nil, bundleIdentifier: frontmostID)
        frontmostID = app.bundleIdentifier
        runtime.setProfileApplicationRemappingOverride(true, bundleIdentifier: frontmostID, hasAssignedProfile: true)
        XCTAssertTrue(tap.foregroundApplicationAllowsRemapping)

        runtime.setForegroundApplicationScope(.init(excludedApplications: [app]))
        runtime.enable()
        XCTAssertFalse(runtime.isManualControlOn)
        XCTAssertFalse(tap.foregroundApplicationAllowsRemapping)
    }

    func testAutomaticEnablePreservesManualSettingAndStopsWhenLeavingApp() {
        let tap = ControllerMockEventTapManager()
        let runtime = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(), rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(), eventTapManager: tap
        )
        runtime.setProfileApplicationRemappingOverride(true, bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(runtime.state, .enabled)
        XCTAssertFalse(runtime.isManualRemappingEnabled)
        runtime.setProfileApplicationRemappingOverride(nil, bundleIdentifier: "other")
        XCTAssertEqual(runtime.state, .disabled)
        XCTAssertFalse(tap.isRunning)
        XCTAssertFalse(runtime.isManualRemappingEnabled)
    }

    func testExcludedAppsOverrideProfileEnableAndFailureOverridesGlobalInclude() {
        let runtime = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(), rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(), eventTapManager: ControllerMockEventTapManager(),
            foregroundApplicationBundleIdentifierProvider: { self.app.bundleIdentifier }
        )
        var inactive = app
        inactive.isEnabled = false
        runtime.setForegroundApplicationScope(.init(excludedApplications: [inactive]))
        runtime.setProfileApplicationRemappingOverride(true, bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(runtime.foregroundApplicationOverride, true)
        XCTAssertEqual(runtime.state, .enabled)

        runtime.setForegroundApplicationScope(.init(excludedApplications: [app]))
        XCTAssertEqual(runtime.foregroundApplicationOverride, false)
        XCTAssertNotEqual(runtime.state, .enabled)
        runtime.setForegroundApplicationScope(.init(includedApplications: [app]))
        runtime.setProfileApplicationRemappingOverride(false, bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(runtime.foregroundApplicationOverride, false)
        XCTAssertNotEqual(runtime.state, .enabled)
    }

    func testProfileEnableOverridesOtherAppsOffWithoutGrantingTemporaryManualActivation() {
        let runtime = RemappingController(
            permissionService: ControllerMockPermissionService(isGranted: true),
            profilesStore: ControllerMockRulesStore(), rulesValidator: RemappingRulesValidator(),
            remappingEngine: RemappingEngine(), eventTapManager: ControllerMockEventTapManager()
        )
        runtime.setForegroundApplicationScope(.init(allowsOtherApplications: false, allowsManualActivationForOtherApplications: true))
        runtime.setProfileApplicationRemappingOverride(true, bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(runtime.state, .enabled)
        XCTAssertFalse(runtime.usesTemporaryManualActivation)
        runtime.setProfileApplicationRemappingOverride(nil, bundleIdentifier: "other")
        XCTAssertNotEqual(runtime.state, .enabled)
        XCTAssertTrue(runtime.usesTemporaryManualActivation)
        XCTAssertFalse(runtime.isManualControlOn)
    }

    func testAutomaticEnableDoesNotRequestAccessibilityPermission() {
        let permission = ControllerMockPermissionService(isGranted: false)
        let runtime = RemappingController(
            permissionService: permission, profilesStore: ControllerMockRulesStore(),
            rulesValidator: RemappingRulesValidator(), remappingEngine: RemappingEngine(),
            eventTapManager: ControllerMockEventTapManager()
        )
        runtime.setProfileApplicationRemappingOverride(true, bundleIdentifier: app.bundleIdentifier)
        XCTAssertEqual(runtime.state, .permissionRequired)
        XCTAssertEqual(permission.requestAccessCallCount, 0)
    }

    func testAppsButtonInvokesCorrectProfileAfterSortingAtEveryLayoutStage() {
        _ = NSApplication.shared
        let first = RemappingProfile(name: "Zulu")
        let second = RemappingProfile(name: "Alpha")
        let config = configuration([first, second])
        let session = HomeConfigurationEditorSession(snapshot: .init(
            profilesConfiguration: config, launchBehavior: .alwaysOff, shortcutConfiguration: .disabled
        ))
        let view = HomeProfilesSectionView(editorSession: session, initialConfiguration: config)
        var selected: [UUID] = []
        view.onEditApplications = { selected.append($0) }
        for stage in HomeProfilesTableLayout.Stage.allCases {
            XCTAssertTrue(view.performApplicationsActionClickForTesting(at: 0, stage: stage))
        }
        XCTAssertEqual(selected, Array(repeating: second.id, count: HomeProfilesTableLayout.Stage.allCases.count))
        XCTAssertFalse(session.hasUnsavedChanges)
    }
}
