//
//  RemappingController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/15/26.
//

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

/// Coordinates permissions, rule validation, storage,
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

    private let rulesStore:
        RulesStore

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

    private var isKeyCaptureActive = false

    private(set) var state:
        RemappingState = .disabled

    var onStateChange:
        ((RemappingState) -> Void)?

    init(
        permissionService:
            AccessibilityPermissionChecking,
        rulesStore:
            RulesStore,
        rulesValidator:
            RemappingRulesValidating,
        remappingEngine:
            RemappingEngine,
        eventTapManager:
            EventTapManaging,
        shortcutConfigurationProvider:
            @escaping () -> RemappingShortcutConfiguration = {
                .disabled
            }
    ) {
        self.permissionService =
            permissionService

        self.rulesStore =
            rulesStore

        self.rulesValidator =
            rulesValidator

        self.remappingEngine =
            remappingEngine

        self.eventTapManager =
            eventTapManager

        self.shortcutConfigurationProvider =
            shortcutConfigurationProvider
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
                try rulesStore
                    .loadRules()
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

    /// Returns the rules currently stored by the application.
    func loadConfiguredRules()
        throws -> [RemapRule]
    {
        try rulesStore
            .loadRules()
    }

    /// Validates and replaces all configured rules.
    ///
    /// Structural rule validation and shortcut-conflict validation are both
    /// completed before storage or the prepared runtime engine is modified.
    ///
    /// This guarantees that a rule cannot become active merely because the
    /// conflicting shortcut was configured first.
    func replaceConfiguredRules(
        _ rules:
            [RemapRule]
    ) throws {
        try validate(
            rules
        )

        try rulesStore
            .saveRules(
                rules
            )

        remappingEngine
            .replaceRules(
                rules
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
