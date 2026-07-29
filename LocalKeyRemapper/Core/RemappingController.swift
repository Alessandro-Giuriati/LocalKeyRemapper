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

    /// Returns the complete shortcut configuration currently stored
    /// in application preferences.
    ///
    /// The provider is evaluated whenever rules are saved or activated,
    /// ensuring conflicts are detected regardless of which configuration
    /// was created first.
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

        let rules:
            [RemapRule]

        do {
            rules =
                try loadConfiguredRules()
        } catch {
            updateState(
                .failed(
                    .rulesLoadingFailed
                )
            )

            return
        }

        do {
            try validate(
                rules
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
                rules
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
    /// When Accessibility permission was revoked, the invalid tap is
    /// removed immediately and the controller enters the
    /// permission-required state. Transient interruptions are recovered
    /// by creating a fresh event tap.
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

    /// Revalidates Accessibility permission after a relevant
    /// application or user-interface event.
    ///
    /// This method does not recreate a healthy event tap. It only removes
    /// the tap when permission was revoked, or retries activation after
    /// permission was granted.
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
    ///
    /// This compatibility operation is retained while the Rules window
    /// is converted to open profiles explicitly by UUID.
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
    ///
    /// This compatibility operation is retained while the Rules window
    /// is converted to pass an explicit profile UUID.
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
    /// Saving an inactive profile persists its rules without modifying
    /// the currently prepared runtime engine.
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

    /// Temporarily suspends remapping while the Settings
    /// window captures a physical keyboard key.
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

    /// Ends keyboard capture and restores remapping
    /// when the backend is still enabled.
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

    /// Applies every blocking rule validation policy.
    ///
    /// The shortcut policy uses effective matching behavior, including
    /// Preserve Modifiers, enabled exceptions, disabled rules, and Reverse.
    private func validate(
        _ rules:
            [RemapRule]
    ) throws {
        try rulesValidator
            .validate(
                rules
            )

        try RemappingShortcutRuleConflictPolicy
            .validate(
                rules:
                    rules,
                shortcutConfiguration:
                    shortcutConfigurationProvider()
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

        try validate(
            rules
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
            updatedConfiguration.activeProfileID
                == profileID
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
