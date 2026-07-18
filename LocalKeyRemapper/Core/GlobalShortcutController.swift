//
//  GlobalShortcutController.swift
//  LocalKeyRemapper
//
//  Created by Alessandro Giuriati on 7/17/26.
//

/// Coordinates global shortcut registration, local persistence,
/// validation, and protection from normal remapping rules.
///
/// This controller stores only configured shortcuts.
/// It never receives, records, or logs normal keyboard input.
@MainActor
final class GlobalShortcutController {

    private let shortcutManager:
        GlobalShortcutRegistering

    private let appPreferencesController:
        AppPreferencesControlling

    private let remappingEngine:
        RemappingEngine

    private let actionHandler:
        (
            GlobalShortcutAction
        ) -> Void

    /// Indicates that active global registrations are temporarily
    /// suspended while the Settings window records a shortcut.
    private var isCaptureSuspended = false

    /// The shortcut configuration currently stored
    /// in local application preferences.
    var configuredConfiguration:
        RemappingShortcutConfiguration
    {
        appPreferencesController
            .preferences
            .shortcutConfiguration
    }

    init(
        shortcutManager:
            GlobalShortcutRegistering,
        appPreferencesController:
            AppPreferencesControlling,
        remappingEngine:
            RemappingEngine = RemappingEngine(),
        actionHandler:
            @escaping (
                GlobalShortcutAction
            ) -> Void
    ) {
        self.shortcutManager =
            shortcutManager

        self.appPreferencesController =
            appPreferencesController

        self.remappingEngine =
            remappingEngine

        self.actionHandler =
            actionHandler
    }

    /// Registers and protects the configuration currently stored
    /// in local preferences.
    func start() throws {
        isCaptureSuspended = false

        let configuration =
            configuredConfiguration

        do {
            try applyRegistration(
                for:
                    configuration
            )

            applyReservation(
                for:
                    configuration
            )
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for:
                    .disabled
            )

            throw error
        }
    }

    /// Atomically replaces the complete shortcut configuration.
    ///
    /// Invalid configurations are rejected before any active
    /// registration or reservation is changed.
    ///
    /// If registration or persistence fails, the previous registration
    /// and reservation are restored whenever possible.
    func setConfiguration(
        _ newConfiguration:
            RemappingShortcutConfiguration
    ) throws {
        let previousConfiguration =
            configuredConfiguration

        guard
            previousConfiguration
                != newConfiguration
        else {
            return
        }

        /// Validate before touching the currently active shortcuts.
        ///
        /// This avoids unnecessary unregister/register cycles when
        /// the proposed configuration is invalid.
        try validate(
            newConfiguration
        )

        do {
            try register(
                newConfiguration
            )

            applyReservation(
                for:
                    newConfiguration
            )
        } catch {
            restoreRegistrationAndReservation(
                for:
                    previousConfiguration
            )

            throw error
        }

        do {
            try appPreferencesController
                .setShortcutConfiguration(
                    newConfiguration
                )
        } catch {
            restoreRegistrationAndReservation(
                for:
                    previousConfiguration
            )

            throw error
        }
    }

    /// Compatibility operation for code that still edits
    /// one optional toggle shortcut.
    func setShortcut(
        _ newShortcut:
            KeyCombination?
    ) throws {
        let configuration:
            RemappingShortcutConfiguration

        if let newShortcut {
            configuration =
                .toggle(
                    newShortcut
                )
        } else {
            configuration =
                .disabled
        }

        try setConfiguration(
            configuration
        )
    }

    /// Temporarily removes active Carbon registrations while
    /// the Settings window records a new shortcut.
    func beginShortcutCapture() {
        guard !isCaptureSuspended else {
            return
        }

        isCaptureSuspended = true
        shortcutManager.unregister()
    }

    /// Restores the stored shortcut configuration after capture ends.
    func endShortcutCapture() throws {
        guard isCaptureSuspended else {
            return
        }

        isCaptureSuspended = false

        do {
            try applyRegistration(
                for:
                    configuredConfiguration
            )

            applyReservation(
                for:
                    configuredConfiguration
            )
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for:
                    .disabled
            )

            throw error
        }
    }

    /// Removes all shortcut registrations, the Carbon event handler,
    /// and every protected application combination.
    func stop() {
        isCaptureSuspended = false
        shortcutManager.stop()

        applyReservation(
            for:
                .disabled
        )
    }

    private func applyRegistration(
        for configuration:
            RemappingShortcutConfiguration
    ) throws {
        try validate(
            configuration
        )

        try register(
            configuration
        )
    }

    private func register(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        try shortcutManager.register(
            configuration.registrations,
            actionHandler:
                actionHandler
        )
    }

    private func validate(
        _ configuration:
            RemappingShortcutConfiguration
    ) throws {
        try GlobalShortcutConfigurationPolicy
            .validate(
                configuration
            )
    }

    private func applyReservation(
        for configuration:
            RemappingShortcutConfiguration
    ) {
        remappingEngine
            .replaceReservedCombinations(
                configuration
                    .reservedCombinations
            )
    }

    private func restoreRegistrationAndReservation(
        for configuration:
            RemappingShortcutConfiguration
    ) {
        do {
            try applyRegistration(
                for:
                    configuration
            )

            applyReservation(
                for:
                    configuration
            )
        } catch {
            shortcutManager.unregister()

            applyReservation(
                for:
                    .disabled
            )
        }
    }
}
