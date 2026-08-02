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

    /// Called whenever the remapping state changes.
    var onStateChange: ((RemappingState) -> Void)? { get set }

    /// Enables keyboard remapping when possible.
    func enable()

    /// Disables keyboard remapping and removes the event tap.
    func disable()

    /// Switches between the enabled and disabled states.
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

    private var isKeyCaptureActive = false

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
            }
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
    }

    func enable() {
        guard
            state != .enabled,
            state != .enabling
        else {
            return
        }

        guard permissionService.isGranted else {
            permissionService.requestAccess()

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
                        configuration.activeProfileID,
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

        updateState(
            .enabled
        )
    }

    func disable() {
        eventTapManager.stop()

        updateState(
            .disabled
        )
    }

    func toggle() {
        switch state {
        case .enabled,
             .enabling:
            disable()

        case .disabled,
             .permissionRequired,
             .failed:
            enable()
        }
    }

    /// Handles an event tap interruption reported by Core Graphics.
    ///
    /// When Accessibility permission was revoked, the invalid tap is removed
    /// immediately. Transient interruptions are recovered by creating a fresh
    /// event tap.
    func handleEventTapInterruption() {
        guard
            state == .enabled
                || state == .enabling
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

        updateState(
            .enabled
        )
    }

    /// Revalidates Accessibility permission after a relevant application or
    /// user-interface event.
    func refreshAccessibilityPermission() {
        switch state {
        case .enabled,
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

            updateState(
                .disabled
            )

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
                    configuration.activeProfileID,
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
                configuration.activeProfileID,
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

        guard
            state == .enabled
        else {
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

        guard
            state == .enabled
        else {
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

        let isActiveProfile =
            configuration.activeProfileID
                == profileID

        let effectiveShortcutConfiguration:
            RemappingShortcutConfiguration?

        if isActiveProfile {
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
            RemappingState
    ) {
        guard
            state != newState
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
