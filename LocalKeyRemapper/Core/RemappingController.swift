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

/// Coordinates permissions, rules, the remapping engine,
/// and the keyboard event tap.
///
/// This controller does not process individual keyboard events
/// and does not store or log keyboard input.
@MainActor
final class RemappingController: RemappingControlling {

    private let permissionService: AccessibilityPermissionChecking
    private let rulesStore: RulesStore
    private let remappingEngine: RemappingEngine
    private let eventTapManager: EventTapManaging

    private var isKeyCaptureActive = false

    private(set) var state: RemappingState = .disabled

    var onStateChange: ((RemappingState) -> Void)?

    init(
        permissionService: AccessibilityPermissionChecking,
        rulesStore: RulesStore,
        remappingEngine: RemappingEngine,
        eventTapManager: EventTapManaging
    ) {
        self.permissionService = permissionService
        self.rulesStore = rulesStore
        self.remappingEngine = remappingEngine
        self.eventTapManager = eventTapManager
    }

    func enable() {
        guard state != .enabled && state != .enabling else {
            return
        }

        guard permissionService.isGranted else {
            permissionService.requestAccess()
            updateState(.permissionRequired)
            return
        }

        updateState(.enabling)

        let rules: [RemapRule]

        do {
            rules = try rulesStore.loadRules()
        } catch {
            updateState(
                .failed(.rulesLoadingFailed)
            )
            return
        }

        remappingEngine.replaceRules(rules)

        do {
            try eventTapManager.start()
        } catch {
            eventTapManager.stop()

            updateState(
                .failed(.eventTapStartFailed)
            )
            return
        }

        if isKeyCaptureActive {
            eventTapManager.pause()
        }

        updateState(.enabled)
    }

    func disable() {
        eventTapManager.stop()
        updateState(.disabled)
    }

    func toggle() {
        switch state {
        case .enabled, .enabling:
            disable()

        case .disabled, .permissionRequired, .failed:
            enable()
        }
    }

    /// Returns the rules currently stored by the application.
    func loadConfiguredRules() throws -> [RemapRule] {
        try rulesStore.loadRules()
    }

    /// Replaces all configured rules.
    ///
    /// The prepared dictionary inside RemappingEngine is updated
    /// immediately without restarting the event tap.
    func replaceConfiguredRules(
        _ rules: [RemapRule]
    ) throws {
        try rulesStore.saveRules(rules)
        remappingEngine.replaceRules(rules)
    }

    /// Temporarily suspends remapping while the Settings
    /// window captures a physical keyboard key.
    func beginKeyCapture() {
        guard !isKeyCaptureActive else {
            return
        }

        isKeyCaptureActive = true

        guard state == .enabled else {
            return
        }

        eventTapManager.pause()
    }

    /// Ends keyboard capture and restores remapping
    /// when the backend is still enabled.
    func endKeyCapture() {
        guard isKeyCaptureActive else {
            return
        }

        isKeyCaptureActive = false

        guard state == .enabled else {
            return
        }

        eventTapManager.resume()
    }

    private func updateState(_ newState: RemappingState) {
        guard state != newState else {
            return
        }

        state = newState
        onStateChange?(newState)
    }
}
