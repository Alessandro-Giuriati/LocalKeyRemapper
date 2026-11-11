//
//  RemappingController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

import Foundation

/// Represents a failure while resolving one profile by its stable identity.
nonisolated enum RemappingProfileRulesAccessError:
    Error,
    Equatable
{
    case profileNotFound(UUID)
}

/// Defines the operations exposed by the remapping controller
/// to the application user interface.
@MainActor
protocol RemappingControlling: AnyObject {

    /// Represents the current backend state.
    var state: RemappingState { get }

    /// The manual setting restored whenever the foreground app follows it.
    var isManualRemappingEnabled: Bool { get }

    /// The value edited by the switch in the current app.
    var isManualControlOn: Bool { get }

    var usesTemporaryManualActivation: Bool { get }

    /// An explicit app rule overrides the manual setting while in the foreground.
    var foregroundApplicationOverride: Bool? { get }

    /// Called whenever the runtime state or its manual setting changes.
    var onStateChange: ((RemappingState) -> Void)? { get set }

    /// Turns on the current manual control, subject to the app rule.
    func enable()

    /// Turns off the current manual control, subject to the app rule.
    func disable()

    /// Toggles the manual control for the current foreground context.
    func toggle()
}

/// Coordinates permissions, profile resolution, rule validation, storage,
/// the remapping engine, and the keyboard event tap.
///
/// This controller does not process individual keyboard events
/// and does not store or log keyboard input.
@MainActor
final class RemappingController:
    RemappingControlling,
    RemappingSettingsControlling
{
    private let permissionService:
        AccessibilityPermissionChecking

    private let profilesStore:
        RemappingProfilesStore

    private let rulesValidator:
        RemappingRulesValidating

    private let remappingEngine:
        RemappingEngine

    private let eventTapManager:
        EventTapManaging

    /// Returns the application-wide default shortcut configuration.
    ///
    /// The effective active-profile configuration is resolved by combining this
    /// value with the active profile's optional override.
    private let shortcutConfigurationProvider:
        () -> RemappingShortcutConfiguration

    /// Supplies modification dates when a profile's rules change.
    ///
    /// Injection keeps controller tests deterministic.
    private let dateProvider:
        () -> Date

    private let foregroundApplicationBundleIdentifierProvider: () -> String?
    private let interfaceBundleIdentifier: String?
    private var foregroundApplicationScope = ForegroundApplicationScope.unrestricted
    private(set) var isManualRemappingEnabled = false
    private(set) var foregroundApplicationOverride: Bool?
    private var foregroundApplicationBundleIdentifier: String?
    private var profileApplicationRemappingOverride: Bool?
    private var hasAssignedForegroundProfile = false
    private var temporaryManualRemappingOverride: Bool?
    private(set) var temporaryActiveProfileID: UUID?
    private var isKeyCaptureActive = false

    private var isRemappingRequested: Bool {
        state == .enabled || state == .pausedForForegroundApplication
    }

    private var isGloballyExcluded: Bool {
        foregroundApplicationScope.excludedApplications.contains {
            $0.bundleIdentifier == foregroundApplicationBundleIdentifier
        }
    }

    private var canTemporarilyEnableRemapping: Bool {
        !isGloballyExcluded && profileApplicationRemappingOverride != false
            && (foregroundApplicationOverride != false
                || foregroundApplicationScope.permitsTemporaryManualActivation(in: foregroundApplicationBundleIdentifier))
    }

    private var shouldRemap: Bool {
        if usesTemporaryManualActivation, let temporaryManualRemappingOverride {
            return temporaryManualRemappingOverride && canTemporarilyEnableRemapping
        }
        return foregroundApplicationOverride ?? isManualRemappingEnabled
    }

    var usesTemporaryManualActivation: Bool {
        hasAssignedForegroundProfile || (profileApplicationRemappingOverride == nil
            && foregroundApplicationScope.permitsTemporaryManualActivation(in: foregroundApplicationBundleIdentifier))
    }

    var isManualControlOn: Bool {
        usesTemporaryManualActivation ? shouldRemap : isManualRemappingEnabled
    }

    func effectiveActiveProfileID(in configuration: RemappingProfilesConfiguration) -> UUID {
        temporaryActiveProfileID ?? configuration.activeProfileID
    }

    func setTemporaryActiveProfileID(_ profileID: UUID?) {
        temporaryActiveProfileID = profileID
    }

    private var foregroundScopedState: RemappingState {
        shouldRemap ? .enabled : .pausedForForegroundApplication
    }

    private(set) var state:
        RemappingState = .disabled

    var onStateChange:
        ((RemappingState) -> Void)?

    init(
        permissionService:
            AccessibilityPermissionChecking,
        profilesStore:
            RemappingProfilesStore,
        rulesValidator:
            RemappingRulesValidating,
        remappingEngine:
            RemappingEngine,
        eventTapManager:
            EventTapManaging,
        shortcutConfigurationProvider:
            @escaping () -> RemappingShortcutConfiguration = {
                .disabled
            },
        dateProvider:
            @escaping () -> Date = {
                Date()
            },
        interfaceBundleIdentifier: String? = nil,
        foregroundApplicationBundleIdentifierProvider: @escaping () -> String? = { nil }
    ) {
        self.permissionService =
            permissionService

        self.profilesStore =
            profilesStore

        self.rulesValidator =
            rulesValidator

        self.remappingEngine =
            remappingEngine

        self.eventTapManager =
            eventTapManager

        self.shortcutConfigurationProvider =
            shortcutConfigurationProvider

        self.dateProvider =
            dateProvider

        self.interfaceBundleIdentifier = interfaceBundleIdentifier
        self.foregroundApplicationBundleIdentifierProvider =
            foregroundApplicationBundleIdentifierProvider
    }

    func enable() {
        refreshForegroundApplicationOverride()
        let manualSettingChanged = !isManualControlOn
        if usesTemporaryManualActivation {
            if canTemporarilyEnableRemapping {
                temporaryManualRemappingOverride = true
            }
        } else {
            isManualRemappingEnabled = true
        }
        reconcileRuntime(requestsPermission: true, notifyIfUnchanged: manualSettingChanged)
    }

    func disable() {
        refreshForegroundApplicationOverride()
        let manualSettingChanged = isManualControlOn
        if usesTemporaryManualActivation {
            temporaryManualRemappingOverride = false
        } else {
            isManualRemappingEnabled = false
        }
        reconcileRuntime(requestsPermission: false, notifyIfUnchanged: manualSettingChanged)
    }

    /// Restores the saved baseline without granting a temporary app activation.
    func restoreManualSettingAtLaunch(_ isEnabled: Bool) {
        let manualSettingChanged = isManualRemappingEnabled != isEnabled
        isManualRemappingEnabled = isEnabled
        temporaryManualRemappingOverride = nil
        refreshForegroundApplicationOverride()
        reconcileRuntime(requestsPermission: isEnabled, notifyIfUnchanged: manualSettingChanged)
    }

    /// Releases the backend when the application shuts down.
    func stop() {
        eventTapManager.stop()
        isManualRemappingEnabled = false
        foregroundApplicationScope = .unrestricted
        foregroundApplicationOverride = nil
        profileApplicationRemappingOverride = nil
        foregroundApplicationBundleIdentifier = nil
        hasAssignedForegroundProfile = false
        temporaryManualRemappingOverride = nil
        temporaryActiveProfileID = nil
        updateState(.disabled)
    }

    func toggle() {
        refreshForegroundApplicationOverride()
        switch state {
        case .permissionRequired, .failed:
            enable()
        default:
            if isManualControlOn {
                disable()
            } else {
                enable()
            }
        }
    }

    private func startRuntime(requestsPermission: Bool) {
        guard permissionService.isGranted else {
            if requestsPermission {
                permissionService.requestAccess()
            }

            updateState(
                .permissionRequired
            )

            return
        }

        updateState(
            .enabling
        )

        let activeProfile:
            RemappingProfile

        do {
            let configuration =
                try profilesStore
                    .loadConfiguration()

            activeProfile =
                try profile(
                    id:
                        effectiveActiveProfileID(in: configuration),
                    in:
                        configuration
                )
        } catch {
            updateState(
                .failed(
                    .rulesLoadingFailed
                )
            )

            return
        }

        let effectiveShortcutConfiguration =
            EffectiveRemappingShortcutConfigurationResolver
                .resolve(
                    profile:
                        activeProfile,
                    defaultConfiguration:
                        shortcutConfigurationProvider()
                )

        do {
            try validate(
                activeProfile.rules,
                shortcutConfiguration:
                    effectiveShortcutConfiguration
            )
        } catch {
            updateState(
                .failed(
                    .invalidRules
                )
            )

            return
        }

        remappingEngine
            .replaceRules(
                activeProfile.rules
            )

        eventTapManager.setForegroundApplicationAllowsRemapping(shouldRemap)

        do {
            try eventTapManager
                .start()
        } catch {
            eventTapManager.stop()

            updateState(
                .failed(
                    .eventTapStartFailed
                )
            )

            return
        }

        if isKeyCaptureActive {
            eventTapManager.pause()
        }

        updateState(foregroundScopedState)
    }

    /// Applies a committed scope while preserving the manual setting.
    func setForegroundApplicationScope(_ scope: ForegroundApplicationScope) {
        guard foregroundApplicationScope != scope else {
            return
        }

        foregroundApplicationScope = scope
        if !hasAssignedForegroundProfile {
            temporaryManualRemappingOverride = nil
        }
        refreshForegroundApplicationOverride()
        reconcileRuntime(requestsPermission: false, notifyIfUnchanged: true)
    }

    /// Called after the target profile's activation transaction succeeds.
    /// A false override fails closed when activation failed; excluded apps
    /// always take priority over a profile's automatic enable option.
    func setProfileApplicationRemappingOverride(
        _ value: Bool?, bundleIdentifier: String?, hasAssignedProfile: Bool = false
    ) {
        guard value != nil || profileApplicationRemappingOverride != nil
            || hasAssignedProfile || hasAssignedForegroundProfile
            || foregroundApplicationScope.observesForegroundApplication else { return }
        _ = applyForegroundApplicationContext(bundleIdentifier)
        if hasAssignedForegroundProfile != hasAssignedProfile {
            temporaryManualRemappingOverride = nil
        }
        hasAssignedForegroundProfile = hasAssignedProfile
        profileApplicationRemappingOverride = value
        _ = applyForegroundApplicationContext(bundleIdentifier)
        reconcileRuntime(requestsPermission: false, notifyIfUnchanged: true)
    }

    func foregroundApplicationDidActivate(bundleIdentifier: @autoclosure () -> String?) {
        guard foregroundApplicationScope.observesForegroundApplication
            || profileApplicationRemappingOverride != nil || hasAssignedForegroundProfile else {
            return
        }

        guard applyForegroundApplicationContext(bundleIdentifier()) else {
            return
        }
        reconcileRuntime(requestsPermission: false, notifyIfUnchanged: true)
    }

    private func refreshForegroundApplicationOverride() {
        // Workspace notifications own the app session. The app's own windows
        // can edit that session without replacing its foreground context.
        if hasAssignedForegroundProfile {
            _ = applyForegroundApplicationContext(foregroundApplicationBundleIdentifier)
            return
        }
        let bundleIdentifier = (foregroundApplicationScope.observesForegroundApplication
            || profileApplicationRemappingOverride != nil)
            ? foregroundApplicationBundleIdentifierProvider()
            : nil
        _ = applyForegroundApplicationContext(bundleIdentifier)
    }

    private func applyForegroundApplicationContext(_ reportedBundleIdentifier: String?) -> Bool {
        // Manual controls may query the workspace while Home is in front.
        // Keep them bound to the same external app as workspace notifications.
        let showingInterface = interfaceBundleIdentifier != nil && reportedBundleIdentifier == interfaceBundleIdentifier
        let bundleIdentifier = showingInterface ? foregroundApplicationBundleIdentifier : reportedBundleIdentifier
        let applicationChanged = foregroundApplicationBundleIdentifier != bundleIdentifier
        if applicationChanged {
            temporaryManualRemappingOverride = nil
            profileApplicationRemappingOverride = nil
            hasAssignedForegroundProfile = false
        }
        foregroundApplicationBundleIdentifier = bundleIdentifier
        let updatedOverride: Bool? = isGloballyExcluded ? false
            : (profileApplicationRemappingOverride ?? foregroundApplicationScope.remappingOverride(in: bundleIdentifier))
        let overrideChanged = foregroundApplicationOverride != updatedOverride
        foregroundApplicationOverride = updatedOverride
        return overrideChanged || (applicationChanged && foregroundApplicationScope.permitsTemporaryManualActivation)
    }

    private func reconcileRuntime(requestsPermission: Bool, notifyIfUnchanged: Bool) {
        // Reuse the paused tap between included apps. The event-tap manager
        // disables delivery after pending remapped releases have completed.
        let retainsAutomaticRuntime = eventTapManager.isRunning
            && (!foregroundApplicationScope.includedApplications.isEmpty
                || foregroundApplicationScope.permitsTemporaryManualActivation
                || hasAssignedForegroundProfile)
        let needsRuntime = isManualRemappingEnabled || shouldRemap || retainsAutomaticRuntime

        guard needsRuntime else {
            if eventTapManager.isRunning {
                eventTapManager.stop()
            }
            updateState(.disabled, notifyIfUnchanged: notifyIfUnchanged)
            return
        }

        eventTapManager.setForegroundApplicationAllowsRemapping(shouldRemap)
        guard eventTapManager.isRunning else {
            startRuntime(requestsPermission: requestsPermission)
            return
        }

        updateState(foregroundScopedState, notifyIfUnchanged: notifyIfUnchanged)
    }

    /// Handles an event tap interruption reported by Core Graphics.
    ///
    /// When Accessibility permission was revoked, the invalid tap is removed
    /// immediately. Transient interruptions are recovered by creating a fresh
    /// event tap.
    func handleEventTapInterruption() {
        guard
            isRemappingRequested || state == .enabling
        else {
            return
        }

        eventTapManager.stop()

        guard permissionService.isGranted else {
            updateState(
                .permissionRequired
            )

            return
        }

        do {
            try eventTapManager.start()
        } catch {
            eventTapManager.stop()

            if permissionService.isGranted {
                updateState(
                    .failed(
                        .eventTapStartFailed
                    )
                )
            } else {
                updateState(
                    .permissionRequired
                )
            }

            return
        }

        if isKeyCaptureActive {
            eventTapManager.pause()
        }

        updateState(foregroundScopedState)
    }

    /// Revalidates Accessibility permission after a relevant application or
    /// user-interface event.
    func refreshAccessibilityPermission() {
        switch state {
        case .enabled,
             .pausedForForegroundApplication,
             .enabling:
            guard
                !permissionService
                    .isGranted
            else {
                return
            }

            eventTapManager.stop()

            updateState(
                .permissionRequired
            )

        case .permissionRequired:
            guard
                permissionService
                    .isGranted
            else {
                return
            }

            reconcileRuntime(requestsPermission: false, notifyIfUnchanged: false)

        case .disabled,
             .failed:
            break
        }
    }

    /// Returns the rules belonging to the currently active profile.
    func loadConfiguredRules()
        throws -> [RemapRule]
    {
        let configuration =
            try profilesStore
                .loadConfiguration()

        let activeProfile =
            try profile(
                id:
                    effectiveActiveProfileID(in: configuration),
                in:
                    configuration
            )

        return activeProfile.rules
    }

    /// Returns the rules belonging to one specific profile.
    func loadConfiguredRules(
        for profileID: UUID
    ) throws -> [RemapRule] {
        let configuration =
            try profilesStore
                .loadConfiguration()

        let requestedProfile =
            try profile(
                id:
                    profileID,
                in:
                    configuration
            )

        return requestedProfile.rules
    }

    /// Validates and replaces the active profile's rules.
    func replaceConfiguredRules(
        _ rules:
            [RemapRule]
    ) throws {
        let configuration =
            try profilesStore
                .loadConfiguration()

        try replaceConfiguredRules(
            rules,
            for:
                effectiveActiveProfileID(in: configuration),
            in:
                configuration
        )
    }

    /// Validates and replaces the rules belonging to one specific profile.
    ///
    /// Inactive profiles are validated structurally and persisted, but they are
    /// intentionally not compared with any shortcut configuration. They cannot
    /// affect the current runtime until a later Home Save makes them active.
    func replaceConfiguredRules(
        _ rules: [RemapRule],
        for profileID: UUID
    ) throws {
        let configuration =
            try profilesStore
                .loadConfiguration()

        try replaceConfiguredRules(
            rules,
            for:
                profileID,
            in:
                configuration
        )
    }

    /// Temporarily suspends remapping while a window captures a physical key.
    func beginKeyCapture() {
        guard
            !isKeyCaptureActive
        else {
            return
        }

        isKeyCaptureActive = true

        guard isRemappingRequested else {
            return
        }

        eventTapManager.pause()
    }

    /// Ends keyboard capture and restores remapping when appropriate.
    func endKeyCapture() {
        guard
            isKeyCaptureActive
        else {
            return
        }

        isKeyCaptureActive = false

        guard isRemappingRequested else {
            return
        }

        eventTapManager.resume()
    }

    /// Applies structural rule validation and, when supplied, the effective
    /// active-profile shortcut-conflict policy.
    private func validate(
        _ rules:
            [RemapRule],
        shortcutConfiguration:
            RemappingShortcutConfiguration?
    ) throws {
        try rulesValidator
            .validate(
                rules
            )

        guard
            let shortcutConfiguration
        else {
            return
        }

        try RemappingShortcutRuleConflictPolicy
            .validate(
                rules:
                    rules,
                shortcutConfiguration:
                    shortcutConfiguration
            )
    }

    private func replaceConfiguredRules(
        _ rules: [RemapRule],
        for profileID: UUID,
        in configuration:
            RemappingProfilesConfiguration
    ) throws {
        guard
            let profileIndex =
                configuration.profiles
                    .firstIndex(
                        where: {
                            $0.id == profileID
                        }
                    )
        else {
            throw RemappingProfileRulesAccessError
                .profileNotFound(
                    profileID
                )
        }

        let existingProfile =
            configuration
                .profiles[
                    profileIndex
                ]

        let isActiveProfile = effectiveActiveProfileID(in: configuration) == profileID

        let effectiveShortcutConfiguration:
            RemappingShortcutConfiguration?

        if isActiveProfile || configuration.activeProfileID == profileID {
            effectiveShortcutConfiguration =
                EffectiveRemappingShortcutConfigurationResolver
                    .resolve(
                        profile:
                            existingProfile,
                        defaultConfiguration:
                            shortcutConfigurationProvider()
                    )
        } else {
            effectiveShortcutConfiguration =
                nil
        }

        try validate(
            rules,
            shortcutConfiguration:
                effectiveShortcutConfiguration
        )

        var updatedConfiguration =
            configuration

        let rulesChanged =
            updatedConfiguration
                .profiles[
                    profileIndex
                ]
                .rules
                != rules

        updatedConfiguration
            .profiles[
                profileIndex
            ]
            .rules =
                rules

        if rulesChanged {
            updatedConfiguration
                .profiles[
                    profileIndex
                ]
                .updatedAt =
                    dateProvider()
        }

        try profilesStore
            .saveConfiguration(
                updatedConfiguration
            )

        guard
            isActiveProfile
        else {
            return
        }

        remappingEngine
            .replaceRules(
                rules
            )
    }

    private func profile(
        id profileID: UUID,
        in configuration:
            RemappingProfilesConfiguration
    ) throws -> RemappingProfile {
        guard
            let profile =
                configuration.profile(
                    id:
                        profileID
                )
        else {
            throw RemappingProfileRulesAccessError
                .profileNotFound(
                    profileID
                )
        }

        return profile
    }

    private func updateState(
        _ newState:
            RemappingState,
        notifyIfUnchanged: Bool = false
    ) {
        guard
            state != newState || notifyIfUnchanged
        else {
            return
        }

        state =
            newState

        onStateChange?(
            newState
        )
    }
}
